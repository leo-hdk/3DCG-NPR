using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class CameraNormalTexturePass : ScriptableRenderPass
{
    private RenderTargetHandle rtAttachmentHandle;
    private RenderTextureDescriptor descriptor;

    // シェーダの Tags の名前に一致したパスと関連づける
    //private ShaderTagId shaderTagId = new ShaderTagId("CameraNormalTexture");

    // DepthOnly などを使えばでシーン全体のノーマルも書き出せる
    private ShaderTagId shaderTagId = new ShaderTagId("DepthOnly");

    private Material shaderMat = null;
    private FilteringSettings filteringSettings;

    private string PassName => "CameraNormalTexture";

    public string TextureName => "_CameraNormalTexture";

    public CameraNormalTexturePass(RenderQueueRange renderQueueRange, LayerMask layerMask)
    {
        // ビルトインの DepthNormal シェーダを利用
        //shaderMat = CoreUtils.CreateEngineMaterial("Hidden/Internal-DepthNormalsTexture");

        // 自作の独立したシェーダを利用
        shaderMat = new Material(Shader.Find("Hidden/Custom/CameraNormalTexture"));

        filteringSettings = new FilteringSettings(renderQueueRange, layerMask);
    }

    public void Setup(RenderTextureDescriptor baseDescriptor, RenderTargetHandle handle)
    {
        rtAttachmentHandle = handle;
        descriptor = baseDescriptor;
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        cmd.GetTemporaryRT(rtAttachmentHandle.id, descriptor, FilterMode.Point);
        ConfigureTarget(rtAttachmentHandle.id);
        ConfigureClear(ClearFlag.All, Color.black);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get(PassName);

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
        var drawSettings = CreateDrawingSettings(shaderTagId, ref renderingData, sortFlags);
        drawSettings.perObjectData = PerObjectData.None;

        ref CameraData cameraData = ref renderingData.cameraData;
        Camera camera = cameraData.camera;
        if (cameraData.isStereoEnabled)
            context.StartMultiEye(camera);

        // コンストラクタでシェーダからマテリアルを作っている場合はそれで上書きする
        // 上書きしない場合は既存のマテリアルにあるタグのパスがそのまま走る
        if (shaderMat != null)
            drawSettings.overrideMaterial = shaderMat;

        context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);

        cmd.SetGlobalTexture(TextureName, rtAttachmentHandle.id);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        if (rtAttachmentHandle != RenderTargetHandle.CameraTarget)
        {
            cmd.ReleaseTemporaryRT(rtAttachmentHandle.id);
            rtAttachmentHandle = RenderTargetHandle.CameraTarget;
        }
    }
}
