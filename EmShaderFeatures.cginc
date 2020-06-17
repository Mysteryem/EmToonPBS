#ifndef EM_SHADER_FEATURES_INCLUDED
  #define EM_SHADER_FEATURES_INCLUDED

  #ifdef _PARALLAXMAP
      #ifndef HMD_HUE
          #define HMD_HUE
      #endif
  #endif
  #ifdef _SUNDISK_HIGH_QUALITY
      #ifndef FALLBACK_REPLACE_PROBES
          #define FALLBACK_REPLACE_PROBES
      #endif
  #endif
#endif
