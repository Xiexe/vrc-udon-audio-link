﻿using UnityEngine;
using VRC.SDKBase;
using UnityEngine.UI;
using System;

namespace VRCAudioLink
{
#if UDON
using UdonSharp;

#if !COMPILER_UDONSHARP && UNITY_EDITOR
using UnityEditor;
using UdonSharpEditor;
using VRC.Udon;
using VRC.Udon.Common;
using VRC.Udon.Common.Interfaces;
using System.Collections.Immutable;
#endif

public class AudioLink : UdonSharpBehaviour
#else
    public class AudioLink : MonoBehaviour
#endif
    {
        const float AUDIOLINK_VERSION_NUMBER = 2.05f;

        [Header("Main Settings")] [Tooltip("Should be used with AudioLinkInput unless source is 2D. WARNING: if used with a custom 3D audio source (not through AudioLinkInput), audio reactivity will be attenuated by player position away from the Audio Source")]
        public AudioSource audioSource;

        [Header("Basic EQ")] [Range(0.0f, 2.0f)] [Tooltip("Warning: this setting might be taken over by AudioLinkController")]
        public float gain = 1f;

        [Range(0.0f, 2.0f)] [Tooltip("Warning: this setting might be taken over by AudioLinkController")]
        public float bass = 1f;

        [Range(0.0f, 2.0f)] [Tooltip("Warning: this setting might be taken over by AudioLinkController")]
        public float treble = 1f;

        [Header("4 Band Crossover")] [Range(0.0f, 0.168f)] [Tooltip("Bass / low mid crossover")]
        public float x0 = 0.0f;

        [Range(0.242f, 0.387f)] [Tooltip("Bass / low mid crossover")]
        public float x1 = 0.25f;

        [Range(0.461f, 0.628f)] [Tooltip("Low mid / high mid crossover")]
        public float x2 = 0.5f;

        [Range(0.704f, 0.953f)] [Tooltip("High mid / treble crossover")]
        public float x3 = 0.75f;

        [Header("4 Band Threshold Points (Sensitivity)")] [Range(0.0f, 1.0f)] [Tooltip("Bass threshold level (lower is more sensitive)")]
        public float threshold0 = 0.45f;

        [Range(0.0f, 1.0f)] [Tooltip("Low mid threshold level (lower is more sensitive)")]
        public float threshold1 = 0.45f;

        [Range(0.0f, 1.0f)] [Tooltip("High mid threshold level (lower is more sensitive)")]
        public float threshold2 = 0.45f;

        [Range(0.0f, 1.0f)] [Tooltip("Treble threshold level (lower is more sensitive)")]
        public float threshold3 = 0.45f;

        [Header("Fade Controls")] [Range(0.0f, 1.0f)] [Tooltip("Amplitude fade amount. This creates a linear fade-off / trails effect. Warning: this setting might be taken over by AudioLinkController")]
        public float fadeLength = 0.8f;

        [Range(0.0f, 1.0f)] [Tooltip("Amplitude fade exponential falloff. This attenuates the above (linear) fade-off exponentially, creating more of a pulsed effect. Warning: this setting might be taken over by AudioLinkController")]
        public float fadeExpFalloff = 0.3f;

        [Header("Internal (Do not modify)")] public Material audioMaterial;
        public GameObject audioTextureExport;

        [Header("Experimental (Limits performance)")] [Tooltip("Enable Udon audioData array. Required by AudioReactiveLight and AudioReactiveObject. Uses ReadPixels which carries a performance hit. For experimental use when performance is less of a concern")]
        public bool audioDataToggle = false;

        public Color[] audioData;
        public Texture2D audioData2D; // Texture2D reference for hacked Blit, may eventually be depreciated

        private float[] _spectrumValues = new float[1024];
        private float[] _spectrumValuesTrim = new float[1023];
        private float[] _audioFrames = new float[1023 * 4];
        private float[] _samples0 = new float[1023];
        private float[] _samples1 = new float[1023];
        private float[] _samples2 = new float[1023];
        private float[] _samples3 = new float[1023];
        private float _audioLinkInputVolume = 0.01f; // smallify input source volume level
        private bool _audioSource2D = false;

        // Mechanism to provide sync'd instance time to all avatars.
#if UDON
    [UdonSynced]
#endif
        private double _masterInstanceJoinTime;
        private double _elapsedTime = 0;
        private double _elapsedTimeMSW = 0;
        private double _timeOffset = 0;
        private bool   _hasInitializedTime = false;
        private float  _FPSTime = 0;
        private int    _FPSCount = 0;


        private double GetElapsedSecondsSince2019() { return (Networking.GetNetworkDateTime() - new DateTime(2020, 1, 1) ).TotalSeconds; }

        void Start()
        {
            #if UDON
            {
                // Handle sync'd time stuff.
                // OLD NOTES
                //Originally used GetServerTimeInMilliseconds
                //Networking.GetServerTimeInMilliseconds will alias to every 49.7 days (2^32ms). GetServerTimeInSeconds also aliases.
                //We still alias, but TCL suggested using Networking.GetNetworkDateTime.
                //DateTime currentDate = Networking.GetNetworkDateTime();
                //UInt64 currentTimeTicks = (UInt64)(currentDate.Ticks/TimeSpan.TicksPerMillisecond);
                // NEW NOTES
                //We now just compute delta times per frame.

                double startTime = GetElapsedSecondsSince2019();
                
                if (Networking.IsMaster)
                {
                    _masterInstanceJoinTime = startTime;
                    RequestSerialization();
                }
                Debug.Log($"AudioLink Time Sync Debug: IsMaster: {Networking.IsMaster} startTime: {startTime}");
            }
            #endif

            UpdateSettings();
            if (audioSource.name.Equals("AudioLinkInput"))
            {
                audioSource.volume = _audioLinkInputVolume;
            }
            else
            {
                _audioSource2D = true;
            }

            gameObject.SetActive(true); // client disables extra cameras, so set it true
            transform.position = new Vector3(0f, 10000000f, 0f); // keep this in a far away place
        }

        private void Update()
        {
            #if UDON
            if( !_hasInitializedTime )
            {
                if( _masterInstanceJoinTime > 0.00001 )
                {
                    //We can now do our time setup.
                    double Now = GetElapsedSecondsSince2019();
                    _elapsedTime = Now - _masterInstanceJoinTime;
                    Debug.Log( $"AudioLink Time Sync Debug: Received instance time of {_masterInstanceJoinTime} and current time of {Now} delta of {_elapsedTime}" );
                    _hasInitializedTime = true;
                }
                else if( _elapsedTime > 10 && Networking.IsMaster )
                {
                    //Have we gone more than 10 seconds and we're master? 
                    Debug.Log( "AudioLink Time Sync Debug: You were master.  But no _masterInstanceJoinTime was provided for 10 seconds.  Resetting instance time." );
                    _masterInstanceJoinTime = GetElapsedSecondsSince2019();
                    RequestSerialization();
                    _hasInitializedTime = true;
                    _elapsedTime = 0;
                }
            }
            #endif

            // Tested: There does not appear to be any drift updating it this way.
            _elapsedTime += Time.deltaTime;

            _FPSCount++;

            if (_elapsedTime >= _FPSTime)
            {
                audioMaterial.SetVector("_VersionNumberAndFPSProperty", new Vector4(AUDIOLINK_VERSION_NUMBER, 0, _FPSCount, 1));
                _FPSCount = 0;
                _FPSTime++;
                
                // Other things to handle every second.  

                // This handles wrapping of the ElapsedTime so we don't lose precision
                // onthe floating point.
                const double ElapsedTimeMSWBoundary = 1024;
                if( _elapsedTime >= ElapsedTimeMSWBoundary )
                {
                    //For particularly long running instances, i.e. several days, the first
                    //few frames will be spent federating _elapsedTime into _elapsedTimeMSW.
                    _FPSTime = 0;
                    _elapsedTime -= ElapsedTimeMSWBoundary;
                    _elapsedTimeMSW++;
                }
            }

            audioMaterial.SetVector("_AdvancedTimeProps", new Vector4( (float)_elapsedTime, (float)_elapsedTimeMSW,  (float)DateTime.Now.TimeOfDay.TotalSeconds, 0 ) );

            // General Profiling Notes:
            //    Profiling done on 2021-05-26 on an Intel Intel Core i7-8750H CPU @ 2.20GHz
            //    Running loop 255 times (So divide all times by 255)
            //    Base load of system w/o for loop: ~420us in merlin profile land.
            //    With loop, with just summer: 1.2ms / 255
            //    Calling material.SetVeactor( ... new Vector4 ) in the loop:  2.7ms / 255
            //    Setting a float in the loop (to see if there's a difference): 1.9ms / 255
            //                             but setting 4 floats individually... is 3.0ms / 255
            //    The whole shebang with Networking.GetServerTimeInMilliseconds(); 2.3ms / 255
            //    Material.SetFloat with Networking.GetServerTimeInMilliseconds(); 2.3ms / 255
            //    Material.SetFloat with Networking.GetServerTimeInMilliseconds(), twice; 2.9ms / 255
            //    Casting and encoding as UInt32 as 2 floats, to prevent aliasing, twice: 5.1ms / 255
            //    Casting and encoding as UInt32 as 2 floats, to prevent aliasing, once: 3.2ms / 255


            if (audioSource == null) return;
            audioSource.GetOutputData(_audioFrames, 0);
            System.Array.Copy(_audioFrames, 4092 - 1023 * 4, _samples0, 0, 1023);
            System.Array.Copy(_audioFrames, 4092 - 1023 * 3, _samples1, 0, 1023);
            System.Array.Copy(_audioFrames, 4092 - 1023 * 2, _samples2, 0, 1023);
            System.Array.Copy(_audioFrames, 4092 - 1023 * 1, _samples3, 0, 1023);
            audioMaterial.SetFloatArray("_Samples0", _samples0);
            audioMaterial.SetFloatArray("_Samples1", _samples1);
            audioMaterial.SetFloatArray("_Samples2", _samples2);
            audioMaterial.SetFloatArray("_Samples3", _samples3);

        #if UNITY_EDITOR
            UpdateSettings();
        #endif
        }

        void OnPostRender()
        {
            if (audioDataToggle)
            {
                audioData2D.ReadPixels(new Rect(0, 0, audioData2D.width, audioData2D.height), 0, 0, false);
                audioData = audioData2D.GetPixels();
            }
        }

        public void UpdateSettings()
        {
            audioMaterial.SetFloat("_X0", x0);
            audioMaterial.SetFloat("_X1", x1);
            audioMaterial.SetFloat("_X2", x2);
            audioMaterial.SetFloat("_X3", x3);
            audioMaterial.SetFloat("_Threshold0", threshold0);
            audioMaterial.SetFloat("_Threshold1", threshold1);
            audioMaterial.SetFloat("_Threshold2", threshold2);
            audioMaterial.SetFloat("_Threshold3", threshold3);
            audioMaterial.SetFloat("_Gain", gain);
            audioMaterial.SetFloat("_FadeLength", fadeLength);
            audioMaterial.SetFloat("_FadeExpFalloff", fadeExpFalloff);
            audioMaterial.SetFloat("_Bass", bass);
            audioMaterial.SetFloat("_Treble", treble);
            audioMaterial.SetFloat("_AudioSource2D", _audioSource2D ? 1f : 0f);
        }

        private float Remap(float t, float a, float b, float u, float v)
        {
            return ((t - a) / (b - a)) * (v - u) + u;
        }
    }

    #if !COMPILER_UDONSHARP && UNITY_EDITOR && UDON
    [CustomEditor(typeof(AudioLink))]
    public class AudioLinkEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target)) return;
            EditorGUILayout.Space();
            if (GUILayout.Button(new GUIContent("Link all sound reactive objects to this AudioLink", "Links all UdonBehaviours with 'audioLink' parameter to this object."))) { LinkAll(); }
            EditorGUILayout.Space();
            base.OnInspectorGUI();
        }

        void LinkAll()
        {
            UdonBehaviour[] allBehaviours = UnityEngine.Object.FindObjectsOfType<UdonBehaviour>();
            foreach (UdonBehaviour behaviour in allBehaviours)
            {
                var program = behaviour.programSource.SerializedProgramAsset.RetrieveProgram();
                ImmutableArray<string> exportedSymbolNames = program.SymbolTable.GetExportedSymbols();
                foreach (string exportedSymbolName in exportedSymbolNames)
                {
                    if (exportedSymbolName.Equals("audioLink"))
                    {
                        var variableValue = UdonSharpEditorUtility.GetBackingUdonBehaviour((UdonSharpBehaviour)target);
                        System.Type symbolType = program.SymbolTable.GetSymbolType(exportedSymbolName);
                        if (!behaviour.publicVariables.TrySetVariableValue("audioLink", variableValue))
                        {
                            if (!behaviour.publicVariables.TryAddVariable(CreateUdonVariable(exportedSymbolName, variableValue, symbolType)))
                            {
                                Debug.LogError($"Failed to set public variable '{exportedSymbolName}' value.");
                            }

                            if(PrefabUtility.IsPartOfPrefabInstance(behaviour))
                            {
                                PrefabUtility.RecordPrefabInstancePropertyModifications(behaviour);
                            }
                        }
                    }
                }
            }
        }

        IUdonVariable CreateUdonVariable(string symbolName, object value, System.Type type)
        {
            System.Type udonVariableType = typeof(UdonVariable<>).MakeGenericType(type);
            return (IUdonVariable)Activator.CreateInstance(udonVariableType, symbolName, value);
        }

    }
    #endif
}