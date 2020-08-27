using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PfxVolume : VolumeComponent, IPostProcessComponent
{
    [Tooltip("Tonemap Exposure.")]
    public ClampedFloatParameter exposure = new ClampedFloatParameter(1.0f, 0.0f, 10.0f);

    public bool IsActive() => true;

    public bool IsTileCompatible() => false;
}