using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PfxRenderPass : ScriptableRenderPass
{
    private Material sampleMaterial;
    private RenderTargetIdentifier currentTarget;
    private RenderTargetHandle normalTextureHandle;

    public PfxRenderPass()
    {
        Shader sampleShader = Shader.Find("Hidden/Custom/PfxSample");
        if (sampleShader != null) sampleMaterial = new Material(sampleShader);
    }

    public void SetRenderTarget(RenderTargetIdentifier target, RenderTargetHandle normal)
    {
        this.currentTarget = target;
        this.normalTextureHandle = normal;
    }

    // This method is called before executing the render pass.
    // It can be used to configure render targets and their clear state. Also to create temporary render target textures.
    // When empty this render pass will render to the active camera render target.
    // You should never call CommandBuffer.SetRenderTarget. Instead call <c>ConfigureTarget</c> and <c>ConfigureClear</c>.
    // The render pipeline will ensure target setup and clearing happens in an performance manner.
    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {

    }

    // Here you can implement the rendering logic.
    // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
    // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
    // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (!renderingData.cameraData.postProcessEnabled) return;
        if (renderingData.cameraData.isSceneViewCamera) return;
        PfxVolume volume = VolumeManager.instance.stack.GetComponent<PfxVolume>();

        int exposureId = Shader.PropertyToID("_Exposure");
        sampleMaterial.SetFloat(exposureId, volume.exposure.value);
        
        var cmd = CommandBufferPool.Get("PfxRenderPass");
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        int temp = Shader.PropertyToID("_InputColorTexture");
        int w = renderingData.cameraData.camera.scaledPixelWidth;
        int h = renderingData.cameraData.camera.scaledPixelHeight;
        cmd.GetTemporaryRT(temp, w, h, 0, FilterMode.Point, RenderTextureFormat.ARGB32);
        cmd.Blit(currentTarget, temp);
        
        cmd.SetGlobalTexture("_CameraNormalTexture", normalTextureHandle.id);
        cmd.Blit(temp, currentTarget, sampleMaterial);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    /// Cleanup any allocated resources that were created during the execution of this render pass.
    public override void FrameCleanup(CommandBuffer cmd)
    {
    }
};