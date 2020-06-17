using System;
using UnityEditor;
using UnityEngine;

public class EmToon6PBSShaderGUI : ShaderGUI
{
  
  public enum BlendMode
  {
      Opaque,
      Cutout,
      Fade,   // Old school alpha-blending mode, fresnel does not affect amount of transparency
      Transparent // Physically plausible transparency mode, implemented as alpha pre-multiply
  }
  
  public enum SmoothnessMapChannel
  {
    SpecularMetallicAlpha,
    AlbedoAlpha
  }
  
  private static class Styles
  {
    public static GUIContent uvSetLabel = new GUIContent("Detail UV Set");
    
    public static GUIContent albedoText = new GUIContent("Albedo", "Albedo (RGB) and Transparency (A)");
    public static GUIContent alphaCutoffText = new GUIContent("Alpha Cutoff", "Threshold for alpha cutoff");
    public static GUIContent metallicMapText = new GUIContent("Metallic", "Metallic (R), Smoothness/Smoothness X (A), Smoothness Y (G), Anisotropy (B)");
    public static GUIContent smoothnessText = new GUIContent("Smoothness", "Smoothness/Smoothness X value");
    
    // Specular highlights on/off
    public static GUIContent highlightsText = new GUIContent("Specular Highlights", "Specular Highlights");
    // Reflections on/off
    public static GUIContent reflectionsText = new GUIContent("Reflections", "Glossy Reflections");
    
    public static GUIContent normalMapText = new GUIContent("Normal Map", "Normal Map");
    public static GUIContent occlusionText = new GUIContent("Occlusion", "Occlusion (G)");
    
    public static GUIContent emissionText = new GUIContent("Color", "Emission (RGB)");
    
    public static GUIContent detailMaskText = new GUIContent("Detail Mask", "Mask for Secondary Maps (A)");
    
    public static GUIContent detailAlbedoText = new GUIContent("Detail Albedo x2", "Albedo (RGB) multiplied by 2");
    public static GUIContent detailNormalMapText = new GUIContent("Normal Map", "Normal Map");
    
    public static string primaryMapsText = "Main Maps";
    public static string secondaryMapsText = "Secondary Maps";
    public static string forwardText = "Forward Rendering Options";
    public static string renderingMode = "Rendering Mode";
    public static string advancedText = "Advanced Options";
    public static readonly string[] blendNames = Enum.GetNames(typeof(BlendMode));
    
    // Custom Styles
    public static GUIContent cullingModeText = new GUIContent("Culling Mode", "Culling Mode");
    public static GUIContent hueEnabledText = new GUIContent("Hue Change Effect", "Enable the Hue Change Effect, applies to Albedo and Emission");
    public static GUIContent hueEnabledTextOutlines = new GUIContent("Hue Change Effect", "Enable the Hue Change Effect, applies to Albedo, Emission and Outlines");
    public static GUIContent hueAddOrSetText = new GUIContent("Hue Add Or Set", "Add to the existing hue (0) or ignore the existing hue and set the new hue directly (1). Values between 0 and 1 are not advised");
    public static GUIContent hueMaskText = new GUIContent("Hue Mask", "Hue Mask (Description TODO)");
    public static GUIContent hueShiftText = new GUIContent("Hue Offset", "Offset the hue shift");
    public static GUIContent fixedHueShiftText = new GUIContent("Fixed Hue Offset", "When on, all cameras will see the same hue.\nWhen off, different cameras will have a different pseudo-random hue value applied. Almost every VR user will have a slightly different value. Desktop users and 2D cameras with the same resolution will have the same value.");
    public static GUIContent saturationAdjustText = new GUIContent("Saturation Adjustment", "Adjust Albedo Saturation");
    public static GUIContent metallicText = new GUIContent("Metallic", "Typically a material is either metal or not metal, but most metals will have a small amount of dust or dirt on their surface, so 0.9 may be better for metallic materials. A pure metal won't receive shadows for example, but in a more realistic material, you would see the shadow cast on the dust/dirt on the metal's surface.");
    public static GUIContent smoothnessXText = new GUIContent("Smoothness/Smoothness X", "Smoothness/Smoothness X value");
    public static GUIContent smoothnessYText = new GUIContent("Smoothness Y", "Smoothness Y, used with Anisotropy");
    public static GUIContent anisotropyText = new GUIContent("Anisotropy", "Anisotropy, used with Smoothness X and Smoothness Y for materials like hair and brushed metal that reflect light more or less in different directions. The X and Y directions are determined by the tangent direction of each vertex which are typically calculated from UVs, make sure tangents are imported or calculated in your model import settings. Note that Blender's FBX export doesn't export tangents by default and requires all polygons in your model to have only 3 or 4 sides.");
    public static GUIContent specularColorText = new GUIContent("Specular Color", "Specular Color (rgb) is not normally available with a metallic workflow, but is useful when combined with Toon Specular. Alpha (a) is multiplied with the Toon Specular option to let you have both toon and normal specular on one material.");
    public static GUIContent specularSharpnessText = new GUIContent("Toon Specular", "Control whether normal or toon specular is used, values less than 1 will reduce the toon specular sharpness until the control switches over to normal specular");
    public static GUIContent directionSHSpecularText = new GUIContent("SH Directional Specular", "Enable specular highlights for the most significant lighting direction from Spherical Harmonics (light probes)");
    public static GUIContent reflectionSHSpecularText = new GUIContent("SH Reflection Specular", "Enable specular highlights from Spherical Harmonics based on the view reflection direction");
    public static GUIContent capAnisotropicSpecularText = new GUIContent("Cap Anisotropic Specular", "Particularly bad vertex normals can cause severely bright specular highlights with the currently used anisotropic specular function, turning this on will limit the maximum brightness to fairly sane levels, turn this on if you are using anisotropic specular and get blinded by the specular highlights in worlds with bloom enabled (though you should probably look into fixing the vertex normals on your model)");
    public static GUIContent outlineWidthText = new GUIContent("Outline Width");
    public static GUIContent outlineAlbedoTintText = new GUIContent("Outline Albedo Tint", "0: Vertex colour and outline colour only, 1: Multiplied by albedo colour and texture");
    public static GUIContent outlineLitText = new GUIContent("Lit Outlines", "0: Unlit, 1: Diffuse Lit");
    public static GUIContent outlineWidthMaskText = new GUIContent("Outline Mask", "Width (R), Albedo Tint (G), Lit (B). Note that specular highlights and reflections are excluded from lit outlines.");
    public static GUIContent reflectionFallbackText = new GUIContent("Reflection Fallback", "Specify a cubemap to use as a fallback when a world has no reflection probes. The fallback should be well lit as it will be adjusted in brightness to match the environment");
    public static GUIContent useFallBackInsteadOfProbesText = new GUIContent("Replace Probes", "Use the specified fallback instead of using reflection probes from the world");
    public static GUIContent diffuseControlMapText = new GUIContent("Diffuse Control", "Diffuse Smoothness (R), Diffuse Direction (G), View Direction Forwards Bias (B), **Velvet Boost** (A)");
    public static GUIContent diffuseSmoothnessText = new GUIContent("Diffuse Smoothness", "Blend between sharp (toon-like) and smooth (standard-like) shading. This is done by adjusting vertex normals");
    public static GUIContent diffuseDirectionText = new GUIContent("Diffuse Direction", "Blend between using the light direction (0) to adjust normals and using the object view direction (1). Light direction won't change as the view of the avatar changes. Object view direction gives a rimlight-like effect. With either option, the lighting remains consistent if you rotate your head in-place." +
    "\n\nTo get a better idea of how this works, create a sphere, apply this material, set the Diffuse Smoothness to 0 and have only a single directional light in your scene, then move the Diffuse Direction slider between 0 (toon) to 1 (smooth). " + 
    "\n\nObject view direction has a couple of caveats:" +
    "\n1) It will spin around when seen from directly above or below." +
    "\n2) It uses the average eye position when in VR, but this doesn't work in mirrors, so you'll see slightly different lighting in each eye when looking at yourself in a mirror.");
    public static GUIContent viewDirectionForwardsBiasText = new GUIContent("View Direction Forwards Bias", "Decreases the width of the rimlight-like effect when using the view direction Diffuse Direction. Technically, this adds a bias towards the direction going towards the camera.");
    public static GUIContent shadowSharpnessText = new GUIContent("Shadow Sharpness", "Dynamic shadow sharpness. Works similarly to XSToon");
    public static GUIContent shadowLiftText = new GUIContent("Shadow Lift", "Dynamic shadow lift. Decreases the strength of dynamic shadows. A small amount, ~0.1, is helpful for very poorly lit worlds that have a single dynamic directional light with full strength shadows");
    public static GUIContent emissionMapText = new GUIContent("Emission", "Alpha 0: Additive blending (avatar_lighting + emission)\nAlpha 100: Lighten blending (max(avatar_lighting, emission))");
    public static GUIContent unusedTextureText = new GUIContent("!!! Unused texture !!!");
    
  }
  
  // Custom - Top properties
  MaterialProperty cullingMode = null;
  
  // Custom - Main maps
  MaterialProperty smoothnessY = null;
  MaterialProperty anisotropy = null;
  MaterialProperty capAnisotropicSpecular = null;
  
  // Custom - Secondary Maps
  MaterialProperty reflectionFallback = null;
  MaterialProperty useFallbackInsteadOfProbes = null;
  
  // Custom - Hue
  MaterialProperty hueEnabled = null;
  MaterialProperty hueMask = null;
  MaterialProperty hueShift = null;
  MaterialProperty fixedHueShift = null;
  MaterialProperty hueAddOrSet = null;
  
  // Custom - Outlines
  MaterialProperty outlineColor = null;
  MaterialProperty outlineWidth = null;
  MaterialProperty outlineMask = null;
  MaterialProperty outlineAlbedoTint = null;
  MaterialProperty outlineLit = null;
  
  // Custom - Advanced Options
  //MaterialProperty uvSetPrimary = null;
  MaterialProperty diffuseControlMap = null;
  MaterialProperty saturationAdjust = null;
  MaterialProperty diffuseSmoothness = null;
  MaterialProperty diffuseDirection = null;
  MaterialProperty diffuseViewDirectionBias = null;
  MaterialProperty viewDirectionDiffuseBoost = null;
  MaterialProperty shadowSharpness = null;
  MaterialProperty shadowLift = null;
  MaterialProperty specularSharpness = null;
  MaterialProperty directionalSHSpecular = null;
  MaterialProperty reflectionSHSpecular = null;
  
  // Same as standard
  MaterialProperty blendMode = null;
  MaterialProperty albedoMap = null;
  MaterialProperty albedoColor = null;
  MaterialProperty alphaCutoff = null;
  MaterialProperty specularMap = null;
  MaterialProperty specularColor = null;
  MaterialProperty metallicMap = null;
  MaterialProperty metallic = null;
  MaterialProperty smoothness = null;
  //MaterialProperty smoothnessScale = null;
  MaterialProperty smoothnessMapChannel = null;
  MaterialProperty highlights = null;
  MaterialProperty reflections = null;
  MaterialProperty bumpScale = null;
  MaterialProperty bumpMap = null;
  MaterialProperty occlusionStrength = null;
  MaterialProperty occlusionMap = null;
  //MaterialProperty heightMapScale = null;
  //MaterialProperty heightMap = null;
  // TODO: Use this
  MaterialProperty emissionColor = null;
  MaterialProperty emissionMap = null;
  MaterialProperty detailMask = null;
  MaterialProperty detailAlbedoMap = null;
  MaterialProperty detailNormalMapScale = null;
  MaterialProperty detailNormalMap = null;
  MaterialProperty uvSetSecondary = null;
  
  MaterialEditor m_MaterialEditor;
  
  bool m_FirstTimeApply = true;
  // TODO: Optional control that will force show all controls, even if they won't do anything with the current settings of the other controls. Alternatively, could negate and call this "Hide ineffective properties"
  bool m_ShowAllControls = false;
  static bool m_AlbedoFoldout = true;
  static bool m_MetallicFoldout = true;
  static bool m_NormalFoldout = false;
  static bool m_OcclusionFoldout = false;
  static bool m_EmissionFoldout = false;
  static bool m_DiffuseControlFoldout = true;
  static bool m_DynamicShadowFoldout = false;
  static bool m_HueChangeFoldout = false;
  static bool m_OutlineFoldout = true;
  static bool m_DetailFoldout = false;
  
  bool m_OutlineEnable = false;
  private const float kMaxfp16 = 65536f; // Clamp to a value that fits into fp16.
  ColorPickerHDRConfig m_ColorPickerHDRConfig = new ColorPickerHDRConfig(0f, kMaxfp16, 1 / kMaxfp16, 3f);
  
  //TODO: Only get hue options if we're a hue shader? TODO TODO: Can we activate hue effects with a shader feature?
  //TODO: Only get outline options if we're an outline shader? TODO TODO: Can we activate outline effects with a shader feature? ANSWER: No
  public void FindProperties(MaterialProperty[] props)
  {
      // Custom - Top properties
  cullingMode = FindProperty("_Culling", props);
  
  // Custom - Metallic
  smoothnessY = FindProperty("_SmoothnessY", props);
  anisotropy = FindProperty("_Anisotropy", props);
  capAnisotropicSpecular = FindProperty("_CapAnisoSpecular", props);
  
  // Custom - Secondary Maps
  reflectionFallback = FindProperty("_ReflectionCubemap", props);
  // TODO: Is this a good replacement for the reflections on/off forward rendering option? The code would need to be modified probably
  useFallbackInsteadOfProbes = FindProperty("_Usecubemapinsteadofreflectionprobes", props);
  
  // Custom - Hue
  hueEnabled = FindProperty("_HueEnabled", props);
  hueMask = FindProperty("_HueMask", props);
  hueShift = FindProperty("_HueShift", props);
  fixedHueShift = FindProperty("_FixedHueShift", props);
  hueAddOrSet = FindProperty("_HueAddOrSet", props);
  
  // Custom - Outlines
  outlineWidth = FindProperty("_OutlineWidth", props, false);
  // TODO: Add a [MaterialToggle] with Shader Feature for outlines, but how do we optionally use the "#pragma geometry geom", can we use an "#ifdef Geometry" before it?
  m_OutlineEnable = outlineWidth != null;
  if (m_OutlineEnable) {
      outlineColor = FindProperty("_OutlineColor", props);
      outlineMask = FindProperty("_OutlineMask", props);
      outlineAlbedoTint = FindProperty("_OutlineAlbedoTint", props);
      outlineLit = FindProperty("_OutlineLit", props);
  }
  
  // Custom - Advanced Options
  //MaterialProperty uvSetPrimary = null;
  saturationAdjust = FindProperty("_SaturationAdjustment", props);
  
  diffuseControlMap = FindProperty("_DiffuseControlMap", props);
  diffuseSmoothness = FindProperty("_DiffuseSoftness", props);
  diffuseDirection = FindProperty("_LightOrView", props);
  diffuseViewDirectionBias = FindProperty("_DiffuseViewPull", props);
  viewDirectionDiffuseBoost = FindProperty("_ViewDirectionDiffuseBoost", props);
  
  shadowSharpness = FindProperty("_DynamicShadowSharpness", props);
  shadowLift = FindProperty("_DynamicShadowLift", props);
  
  specularSharpness = FindProperty("_ToonSpecular", props);
  directionalSHSpecular = FindProperty("_ShDirectionalSpecularOn", props);
  reflectionSHSpecular = FindProperty("_ShReflectionSpecularOn", props);
    
    blendMode = FindProperty("_Mode", props);
    albedoMap = FindProperty("_MainTex", props);
    albedoColor = FindProperty("_Color", props);
    alphaCutoff = FindProperty("_Cutoff", props);
    specularMap = FindProperty("_SpecularMap", props);
    specularColor = FindProperty("_SpecularColour", props);
    metallicMap = FindProperty("_MetallicGlossMap", props);
    metallic = FindProperty("_Metallic", props);

    smoothness = FindProperty("_Glossiness", props);
    //smoothnessScale = FindProperty("_GlossMapScale", props, false);
    smoothnessMapChannel = FindProperty("_SmoothnessTextureChannel", props, false);
    highlights = FindProperty("_SpecularHighlights", props, false);
    reflections = FindProperty("_GlossyReflections", props, false);
    bumpScale = FindProperty("_BumpScale", props);
    bumpMap = FindProperty("_BumpMap", props);
    //heigtMapScale = FindProperty("_Parallax", props);
    //heightMap = FindProperty("_ParallaxMap", props);
    occlusionStrength = FindProperty("_OcclusionStrength", props);
    occlusionMap = FindProperty("_OcclusionMap", props);
    emissionColor = FindProperty("_EmissionColor", props);
    emissionMap = FindProperty("_EmissionMap", props);
    detailMask = FindProperty("_DetailMask", props);
    detailAlbedoMap = FindProperty("_DetailAlbedoMap", props);
    detailNormalMapScale = FindProperty("_DetailNormalMapScale", props);
    detailNormalMap = FindProperty("_DetailNormalMap", props);
    uvSetSecondary = FindProperty("_UVSec", props);
  }
  
  public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
  {
    FindProperties(props); // MaterialProperties can be animated so we do not cache them but fetch them every event to ensure animated values are updated correctly
    m_MaterialEditor = materialEditor;
    Material material = materialEditor.target as Material;

    // Make sure that needed setup (ie keywords/renderqueue) are set up if we're switching some existing
    // material to a standard shader.
    // Do this before any GUI code has been issued to prevent layout issues in subsequent GUILayout statements (case 780071)
    if (m_FirstTimeApply)
    {
      MaterialChanged(material/*, m_WorkflowMode*/);
      m_FirstTimeApply = false;
    }

    ShaderPropertiesGUI(material);
  }
  
  public void ShaderPropertiesGUI(Material material)
  {
      // Use default labelWidth
      EditorGUIUtility.labelWidth = 0f;

      // Detect any changes to the material
      EditorGUI.BeginChangeCheck();
      {
          BlendModePopup();
          
          // Custom culling options
          DoCustomCullingArea();

          // Primary properties
          //GUILayout.Label(Styles.primaryMapsText, EditorStyles.boldLabel);
          if (m_AlbedoFoldout = EditorGUILayout.Foldout(m_AlbedoFoldout, "Albedo", true))
              DoAlbedoArea(material);
          EditorGUILayout.Space();
          if (m_MetallicFoldout = EditorGUILayout.Foldout(m_MetallicFoldout, "Metallic/Specular/Reflections", true))
              DoSpecularMetallicArea();
          EditorGUILayout.Space();
          if (m_NormalFoldout = EditorGUILayout.Foldout(m_NormalFoldout, "Normal Map", true))
              DoNormalArea();
          //m_MaterialEditor.TexturePropertySingleLine(Styles.heightMapText, heightMap, heightMap.textureValue != null ? heigtMapScale : null);
          
          EditorGUILayout.Space();
          if (m_OcclusionFoldout = EditorGUILayout.Foldout(m_OcclusionFoldout, "Occlusion/Rim Light", true)) {
              bool hasOcculsionMap = occlusionMap.textureValue != null;
              m_MaterialEditor.TexturePropertySingleLine(Styles.occlusionText, occlusionMap, hasOcculsionMap ? occlusionStrength : null);
              if (hasOcculsionMap)
                  m_MaterialEditor.TextureScaleOffsetProperty(occlusionMap);
          }
          EditorGUILayout.Space();
          //DoEmissionArea(material);
          if (m_EmissionFoldout = EditorGUILayout.Foldout(m_EmissionFoldout, "Emission", true))
              DoCustomEmissionArea();
          
          // Custom
          EditorGUILayout.Space();
          if (m_DiffuseControlFoldout = EditorGUILayout.Foldout(m_DiffuseControlFoldout, "Diffuse Control", true))
              DoCustomDiffuseControlArea();
          EditorGUILayout.Space();
          if (m_DynamicShadowFoldout = EditorGUILayout.Foldout(m_DynamicShadowFoldout, "Dynamic Shadows", true))
              DoCustomShadowsControlArea();
          EditorGUILayout.Space();
          if (m_HueChangeFoldout = EditorGUILayout.Foldout(m_HueChangeFoldout, "Hue Change", true))
              DoCustomHueArea();
          EditorGUILayout.Space();
          if (m_OutlineEnable && (m_OutlineFoldout = EditorGUILayout.Foldout(m_OutlineFoldout, "Outlines", true)))
              DoCustomOutlineArea();
          EditorGUILayout.Space();
          
          if (m_DetailFoldout = EditorGUILayout.Foldout(m_DetailFoldout, "Detail (Not Yet Implemented)", true)) {
              // Detail mask
              m_MaterialEditor.TexturePropertySingleLine(Styles.detailMaskText, detailMask);
              if (detailMask.textureValue != null)
                  m_MaterialEditor.TextureScaleOffsetProperty(detailMask);
              
              //EditorGUI.BeginChangeCheck();
              //m_MaterialEditor.TextureScaleOffsetProperty(albedoMap);
              //if (EditorGUI.EndChangeCheck())
              //    emissionMap.textureScaleAndOffset = albedoMap.textureScaleAndOffset; // Apply the main texture scale and offset to the emission texture as well, for Enlighten's sake

              EditorGUILayout.Space();

              // Secondary properties
              //GUILayout.Label(Styles.secondaryMapsText, EditorStyles.boldLabel);
              m_MaterialEditor.TexturePropertySingleLine(Styles.detailAlbedoText, detailAlbedoMap);
              if (detailAlbedoMap.textureValue != null)
                  m_MaterialEditor.TextureScaleOffsetProperty(detailAlbedoMap);
              m_MaterialEditor.TexturePropertySingleLine(Styles.detailNormalMapText, detailNormalMap, detailNormalMapScale);
              if (detailNormalMap.textureValue != null)
                  m_MaterialEditor.TextureScaleOffsetProperty(detailNormalMap);
              m_MaterialEditor.ShaderProperty(uvSetSecondary, Styles.uvSetLabel.text);
          }
      }
      if (EditorGUI.EndChangeCheck())
      {
          foreach (var obj in blendMode.targets)
              MaterialChanged((Material)obj/*, m_WorkflowMode*/);
      }

      //EditorGUILayout.Space();

      // Neither of these options are supported with the shader, skinned mesh renderers cannot be instanced and there is no baked lightmap support in the shader
      // NB renderqueue editor is not shown on purpose: we want to override it based on blend mode
      //GUILayout.Label(Styles.advancedText, EditorStyles.boldLabel);
      //m_MaterialEditor.EnableInstancingField();
      //m_MaterialEditor.DoubleSidedGIField();
  }
  
  internal void DetermineWorkflow(MaterialProperty[] props)
  {
    //no-op, we deleted everything from this method
  }
  
  public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
  {
      // _Emission property is lost after assigning Standard shader to the material
      // thus transfer it before assigning the new shader
      if (material.HasProperty("_Emission"))
      {
          material.SetColor("_EmissionColor", material.GetColor("_Emission"));
      }

      base.AssignNewShaderToMaterial(material, oldShader, newShader);
      
      if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
      {
          SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));
          return;
      }

      BlendMode blendMode = BlendMode.Opaque;
      if (oldShader.name.Contains("/Transparent/Cutout/"))
      {
          blendMode = BlendMode.Cutout;
      }
      else if (oldShader.name.Contains("/Transparent/"))
      {
          // NOTE: legacy shaders did not provide physically based transparency
          // therefore Fade mode
          blendMode = BlendMode.Fade;
      }
      material.SetFloat("_Mode", (float)blendMode);
      
      MaterialChanged(material/*, m_WorkflowMode*/);
  }
  
  void BlendModePopup()
  {
      EditorGUI.showMixedValue = blendMode.hasMixedValue;
      var mode = (BlendMode)blendMode.floatValue;
      
      EditorGUI.BeginChangeCheck();
      mode = (BlendMode)EditorGUILayout.Popup(Styles.renderingMode, (int)mode, Styles.blendNames);
      if (EditorGUI.EndChangeCheck())
      {
          m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
          blendMode.floatValue = (float)mode;
      }
      
      EditorGUI.showMixedValue = false;
  }
  
  void DoNormalArea()
  {
      bool hasBumpMap = bumpMap.textureValue != null;
      m_MaterialEditor.TexturePropertySingleLine(Styles.normalMapText, bumpMap, hasBumpMap ? bumpScale : null);
      if (hasBumpMap)
        m_MaterialEditor.TextureScaleOffsetProperty(bumpMap);
      if (bumpScale.floatValue != 1
          && UnityEditorInternal.InternalEditorUtility.IsMobilePlatform(EditorUserBuildSettings.activeBuildTarget))
          if (m_MaterialEditor.HelpBoxWithButton(
              new GUIContent("Bump scale is not supported on mobile platforms"),
              new GUIContent("Fix Now")))
          {
              bumpScale.floatValue = 1;
          }
  }
  
  void DoAlbedoArea(Material material)
  {
      m_MaterialEditor.TexturePropertySingleLine(Styles.albedoText, albedoMap, albedoColor);
      if (albedoMap.textureValue != null)
          m_MaterialEditor.TextureScaleOffsetProperty(albedoMap);
      if (((BlendMode)material.GetFloat("_Mode") == BlendMode.Cutout))
      {
          m_MaterialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoffText.text, MaterialEditor.kMiniTextureFieldLabelIndentLevel + 1);
      }
      // Custom setting
      m_MaterialEditor.ShaderProperty(saturationAdjust, Styles.saturationAdjustText);
  }

  void DoSpecularMetallicArea()
  {
      bool hasGlossMap = false;
      //if (m_WorkflowMode == WorkflowMode.Specular)
      //{
      //    hasGlossMap = specularMap.textureValue != null;
          //m_MaterialEditor.TexturePropertySingleLine(Styles.specularMapText, specularMap, hasGlossMap ? null : specularColor);
      //}
      //else if (m_WorkflowMode == WorkflowMode.Metallic)
      //{
      hasGlossMap = metallicMap.textureValue != null;
      //m_MaterialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap, hasGlossMap ? null : metallic);
      m_MaterialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap);
      if (hasGlossMap)
          m_MaterialEditor.TextureScaleOffsetProperty(metallicMap);
      m_MaterialEditor.ShaderProperty(metallic, Styles.metallicText);
      bool hasAnisotropy = anisotropy.floatValue != 0;
      m_MaterialEditor.ShaderProperty(smoothness, hasAnisotropy ? Styles.smoothnessXText : Styles.smoothnessText);
      m_MaterialEditor.ShaderProperty(anisotropy, Styles.anisotropyText);
      if (hasAnisotropy)
      {
          EditorGUI.indentLevel += 1;
          m_MaterialEditor.ShaderProperty(smoothnessY, Styles.smoothnessYText);
          EditorGUI.indentLevel -= 1;
      }
      // Seems like a good idea, but we do actually get a small amount of specular even when smoothness is 0, this is correct
      //bool hasSpecular = smoothness.floatValue != 0 || (hasAnisotropy && smoothnessY.floatValue != 0);
      if (highlights != null)
          m_MaterialEditor.ShaderProperty(highlights, Styles.highlightsText);
      bool hasSpecular = highlights.floatValue != 0;
      if (hasSpecular)
      {
          EditorGUI.indentLevel += 1;
          m_MaterialEditor.TexturePropertySingleLine(Styles.specularColorText, specularMap, specularColor);
          if (specularMap.textureValue != null)
              m_MaterialEditor.TextureScaleOffsetProperty(specularMap);
          EditorGUI.indentLevel += 1;
          m_MaterialEditor.ShaderProperty(specularSharpness, Styles.specularSharpnessText);
          EditorGUI.indentLevel -= 1;
          m_MaterialEditor.ShaderProperty(directionalSHSpecular, Styles.directionSHSpecularText);
          m_MaterialEditor.ShaderProperty(reflectionSHSpecular, Styles.reflectionSHSpecularText);
          if (hasAnisotropy)
              m_MaterialEditor.ShaderProperty(capAnisotropicSpecular, Styles.capAnisotropicSpecularText);
          EditorGUI.indentLevel -= 1;
      }
      else if (specularMap.textureValue != null)
      {
          EditorGUI.indentLevel += 1;
          EditorGUILayout.LabelField(Styles.unusedTextureText, EditorStyles.boldLabel);
          m_MaterialEditor.TexturePropertySingleLine(Styles.specularColorText, specularMap);
          EditorGUI.indentLevel -= 1;
      }
      if (reflections != null)
      {
          m_MaterialEditor.ShaderProperty(reflections, Styles.reflectionsText);
          if (reflections.floatValue != 0)
          {
              EditorGUI.indentLevel += 1;
              //m_MaterialEditor.TexturePropertySingleLine(Styles.reflectionFallbackText, reflectionFallback);
              m_MaterialEditor.TextureProperty(reflectionFallback, "Reflection fallback", false);
              m_MaterialEditor.ShaderProperty(useFallbackInsteadOfProbes, Styles.useFallBackInsteadOfProbesText);
              EditorGUI.indentLevel -= 1;
          }
          else if (reflectionFallback.textureValue != null)
          {
              EditorGUI.indentLevel += 1;
              EditorGUILayout.LabelField(Styles.unusedTextureText, EditorStyles.boldLabel);
              EditorGUI.indentLevel += 1;
              m_MaterialEditor.TexturePropertySingleLine(Styles.reflectionFallbackText, reflectionFallback);
              EditorGUI.indentLevel -= 2;
          }
      }
      //}

      //bool showSmoothnessScale = hasGlossMap;
      //if (smoothnessMapChannel != null)
      //{
      //    int smoothnessChannel = (int)smoothnessMapChannel.floatValue;
      //    if (smoothnessChannel == (int)SmoothnessMapChannel.AlbedoAlpha)
      //        showSmoothnessScale = true;
      //}

      //int indentation = 2; // align with labels of texture properties
      ////m_MaterialEditor.ShaderProperty(showSmoothnessScale ? smoothnessScale : smoothness, showSmoothnessScale ? Styles.smoothnessScaleText : Styles.smoothnessText, indentation);
      //
      //++indentation;
      //if (smoothnessMapChannel != null)
      //    m_MaterialEditor.ShaderProperty(smoothnessMapChannel, Styles.smoothnessMapChannelText, indentation);
  }
  
  void DoCustomCullingArea()
  {
      m_MaterialEditor.ShaderProperty(cullingMode, Styles.cullingModeText);
  }
  void DoCustomHueArea()
  {
      m_MaterialEditor.ShaderProperty(hueEnabled, m_OutlineEnable ? Styles.hueEnabledTextOutlines : Styles.hueEnabledText);
      if (hueEnabled.floatValue != 0) {
          EditorGUI.indentLevel += 1;
          m_MaterialEditor.TexturePropertySingleLine(Styles.hueMaskText, hueMask);
          if (hueMask.textureValue != null)
              m_MaterialEditor.TextureScaleOffsetProperty(hueMask);
          m_MaterialEditor.ShaderProperty(hueShift, Styles.hueShiftText);
          m_MaterialEditor.ShaderProperty(hueAddOrSet, Styles.hueAddOrSetText);
          m_MaterialEditor.ShaderProperty(fixedHueShift, Styles.fixedHueShiftText);
          EditorGUI.indentLevel -= 1;
      } else if (hueMask.textureValue != null) {
          EditorGUI.indentLevel += 1;
          GUILayout.Label(Styles.unusedTextureText, EditorStyles.boldLabel);
          m_MaterialEditor.TexturePropertySingleLine(Styles.hueMaskText, hueMask);
          //m_MaterialEditor.TextureProperty(hueMask, "Unused texture", false);
          EditorGUI.indentLevel -= 1;
      }
  }
  void DoCustomOutlineArea()
  {
      if (m_OutlineEnable) {
          m_MaterialEditor.ShaderProperty(outlineWidth, Styles.outlineWidthText);
          m_MaterialEditor.ShaderProperty(outlineAlbedoTint, Styles.outlineAlbedoTintText);
          m_MaterialEditor.ShaderProperty(outlineLit, Styles.outlineLitText);
          m_MaterialEditor.TexturePropertySingleLine(Styles.outlineWidthMaskText, outlineMask, outlineColor);
          if (outlineMask.textureValue != null)
              m_MaterialEditor.TextureScaleOffsetProperty(outlineMask);
      }
  }

  void DoCustomDiffuseControlArea()
  {
      m_MaterialEditor.TexturePropertySingleLine(Styles.diffuseControlMapText, diffuseControlMap);
      if (diffuseControlMap.textureValue != null)
          m_MaterialEditor.TextureScaleOffsetProperty(diffuseControlMap);
      m_MaterialEditor.ShaderProperty(diffuseSmoothness, Styles.diffuseSmoothnessText);
      m_MaterialEditor.ShaderProperty(diffuseDirection, Styles.diffuseDirectionText);
      if (diffuseDirection.floatValue != 0)
          m_MaterialEditor.ShaderProperty(diffuseViewDirectionBias, Styles.viewDirectionForwardsBiasText);
      m_MaterialEditor.ShaderProperty(viewDirectionDiffuseBoost, "**Velvet Boost** (WIP)");
  }
  void DoCustomShadowsControlArea()
  {
      m_MaterialEditor.ShaderProperty(shadowSharpness, Styles.shadowSharpnessText);
      m_MaterialEditor.ShaderProperty(shadowLift, Styles.shadowLiftText);
  }
  void DoCustomEmissionArea()
  {
      bool hadEmissionTexture = emissionMap.textureValue != null;
    
      m_MaterialEditor.TexturePropertySingleLine(Styles.emissionMapText, emissionMap, emissionColor);
      if (emissionMap.textureValue != null)
          m_MaterialEditor.TextureScaleOffsetProperty(emissionMap);
      
      // If texture was assigned and color was black set color to white
      float brightness = emissionColor.colorValue.maxColorComponent;
      if (emissionMap.textureValue != null && !hadEmissionTexture && brightness <= 0f)
          emissionColor.colorValue = Color.white;
  }

  static void SetupMaterialWithBlendMode(Material material, BlendMode blendMode)
  {
      switch (blendMode)
      {
          case BlendMode.Opaque:
              material.SetOverrideTag("RenderType", "");
              material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
              material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
              material.SetInt("_ZWrite", 1);
              material.DisableKeyword("_ALPHATEST_ON");
              material.DisableKeyword("_ALPHABLEND_ON");
              material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
              material.renderQueue = -1;
              break;
          case BlendMode.Cutout:
              material.SetOverrideTag("RenderType", "TransparentCutout");
              material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
              material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
              material.SetInt("_ZWrite", 1);
              material.EnableKeyword("_ALPHATEST_ON");
              material.DisableKeyword("_ALPHABLEND_ON");
              material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
              material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
              break;
          case BlendMode.Fade:
              material.SetOverrideTag("RenderType", "Transparent");
              material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
              material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
              material.SetInt("_ZWrite", 0);
              material.DisableKeyword("_ALPHATEST_ON");
              material.EnableKeyword("_ALPHABLEND_ON");
              material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
              material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
              break;
          case BlendMode.Transparent:
              material.SetOverrideTag("RenderType", "Transparent");
              material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
              material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
              material.SetInt("_ZWrite", 0);
              material.DisableKeyword("_ALPHATEST_ON");
              material.DisableKeyword("_ALPHABLEND_ON");
              material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
              material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
              break;
      }
  }

  static SmoothnessMapChannel GetSmoothnessMapChannel(Material material)
  {
      int ch = (int)material.GetFloat("_SmoothnessTextureChannel");
      if (ch == (int)SmoothnessMapChannel.AlbedoAlpha)
          return SmoothnessMapChannel.AlbedoAlpha;
      else
          return SmoothnessMapChannel.SpecularMetallicAlpha;
  }

  static void SetMaterialKeywords(Material material/*, WorkflowMode workflowMode*/)
  {
      // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
      // (MaterialProperty value might come from renderer material property block)
      SetKeyword(material, "_NORMALMAP", material.GetTexture("_BumpMap") || material.GetTexture("_DetailNormalMap"));
      //if (workflowMode == WorkflowMode.Specular)
      //    SetKeyword(material, "_SPECGLOSSMAP", material.GetTexture("_SpecGlossMap"));
      //else if (workflowMode == WorkflowMode.Metallic)
      //    SetKeyword(material, "_METALLICGLOSSMAP", material.GetTexture("_MetallicGlossMap"));
      //SetKeyword(material, "_PARALLAXMAP", material.GetTexture("_ParallaxMap"));
      SetKeyword(material, "_DETAIL_MULX2", material.GetTexture("_DetailAlbedoMap") || material.GetTexture("_DetailNormalMap"));

      // A material's GI flag internally keeps track of whether emission is enabled at all, it's enabled but has no effect
      // or is enabled and may be modified at runtime. This state depends on the values of the current flag and emissive color.
      // The fixup routine makes sure that the material is in the correct state if/when changes are made to the mode or color.
      MaterialEditor.FixupEmissiveFlag(material);
      bool shouldEmissionBeEnabled = (material.globalIlluminationFlags & MaterialGlobalIlluminationFlags.EmissiveIsBlack) == 0;
      SetKeyword(material, "_EMISSION", shouldEmissionBeEnabled);

      if (material.HasProperty("_SmoothnessTextureChannel"))
      {
          SetKeyword(material, "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A", GetSmoothnessMapChannel(material) == SmoothnessMapChannel.AlbedoAlpha);
      }
  }

  static void MaterialChanged(Material material/*, WorkflowMode workflowMode*/)
  {
      SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));

      SetMaterialKeywords(material/*, workflowMode*/);
  }

  static void SetKeyword(Material m, string keyword, bool state)
  {
      if (state)
          m.EnableKeyword(keyword);
      else
          m.DisableKeyword(keyword);
  }
}