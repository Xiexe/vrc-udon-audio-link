Shader "AudioLink/AudioLink"
{
    Properties
    {
        _Gain("Gain", Range(0, 2)) = 1.0
        _FadeLength("Fade Length", Range(0 , 1)) = 0.8
        _FadeExpFalloff("Fade Exp Falloff", Range(0 , 1)) = 0.3
        _Bass("Bass", Range(0 , 4)) = 1.0
        _Treble("Treble", Range(0 , 4)) = 1.0
        _X0("X0", Range(0.0, 0.168)) = 0.25
        _X1("X1", Range(0.242, 0.387)) = 0.25
        _X2("X2", Range(0.461, 0.628)) = 0.5
        _X3("X3", Range(0.704, 0.953)) = 0.75
        _Threshold0("Threshold 0", Range(0.0, 1.0)) = 0.45
        _Threshold1("Threshold 1", Range(0.0, 1.0)) = 0.45
        _Threshold2("Threshold 2", Range(0.0, 1.0)) = 0.45
        _Threshold3("Threshold 3", Range(0.0, 1.0)) = 0.45
        [ToggleUI] _AudioSource2D("Audio Source 2D", float) = 0
        [ToggleUI] _EnableAutogain("Enable Autogain", float) = 1
        _AutogainDerate ("Autogain Derate", Range(.001, .5)) = 0.1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Cull Off
        Lighting Off        
        ZWrite Off
        ZTest Always

        Pass
        {
            CGINCLUDE
            #if UNITY_UV_STARTS_AT_TOP
            #define AUDIO_LINK_ALPHA_START(BASECOORDY) \
                float2 guv = IN.globalTexcoord.xy; \
                uint2 coordinateGlobal = round(guv/_SelfTexture2D_TexelSize.xy - 0.5); \
                uint2 coordinateLocal = uint2(coordinateGlobal.x - BASECOORDY.x, coordinateGlobal.y - BASECOORDY.y);
            #else
            #define AUDIO_LINK_ALPHA_START(BASECOORDY) \
                float2 guv = IN.globalTexcoord.xy; \
                guv.y = 1.-guv.y; \
                uint2 coordinateGlobal = round(guv/_SelfTexture2D_TexelSize.xy - 0.5); \
                uint2 coordinateLocal = uint2(coordinateGlobal.x - BASECOORDY.x, coordinateGlobal.y - BASECOORDY.y);
            #endif

            #pragma target 4.0
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #include "AudioLinkCRT.cginc"
            #include "UnityCG.cginc"
            #include "AudioLink.cginc"
            uniform half4 _SelfTexture2D_TexelSize; 

            cbuffer SampleBuffer {
                float _AudioFrames[1023*4] : packoffset(c0);  
                float _Samples0[1023] : packoffset(c0);
                float _Samples1[1023] : packoffset(c1023);
                float _Samples2[1023] : packoffset(c2046);
                float _Samples3[1023] : packoffset(c3069);
            };

            // AudioLink 4 Band
            uniform float _FadeLength;
            uniform float _FadeExpFalloff;
            uniform float _Gain;
            uniform float _Bass;
            uniform float _Treble;
            uniform float _X0;
            uniform float _X1;
            uniform float _X2;
            uniform float _X3;
            uniform float _Threshold0;
            uniform float _Threshold1;
            uniform float _Threshold2;
            uniform float _Threshold3;
            uniform float _AudioSource2D;

            // Extra Properties
            uniform float _EnableAutogain;
            uniform float _AutogainDerate;

            // Set by Udon
            uniform float4 _AdvancedTimeProps;
            uniform float4 _VersionNumberAndFPSProperty;

            // These may become uniforms set by the controller, keep them named like this for now
            const static float _LogAttenuation = 0.68;
            const static float _ContrastSlope = 0.63;
            const static float _ContrastOffset = 0.62;
            ENDCG

            Name "Pass1AudioDFT"
            CGPROGRAM
            const static float lut[240] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.001, 0.002, 0.003, 0.004, 0.005, 0.006, 0.008, 0.01,
0.012, 0.014, 0.017, 0.02, 0.022, 0.025, 0.029, 0.032, 0.036, 0.04, 0.044, 0.048, 0.053, 0.057, 0.062, 0.067, 0.072, 0.078, 0.083, 0.089,
0.095, 0.101, 0.107, 0.114, 0.121, 0.128, 0.135, 0.142, 0.149, 0.157, 0.164, 0.172, 0.18, 0.188, 0.196, 0.205, 0.213, 0.222, 0.23, 0.239,
0.248, 0.257, 0.266, 0.276, 0.285, 0.294, 0.304, 0.313, 0.323, 0.333, 0.342, 0.352, 0.362, 0.372, 0.381, 0.391, 0.401, 0.411, 0.421, 0.431,
0.441, 0.451, 0.46, 0.47, 0.48, 0.49, 0.499, 0.509, 0.519, 0.528, 0.538, 0.547, 0.556, 0.565, 0.575, 0.584, 0.593, 0.601, 0.61, 0.619,
0.627, 0.636, 0.644, 0.652, 0.66, 0.668, 0.676, 0.684, 0.691, 0.699, 0.706, 0.713, 0.72, 0.727, 0.734, 0.741, 0.747, 0.754, 0.76, 0.766,
0.772, 0.778, 0.784, 0.79, 0.795, 0.801, 0.806, 0.811, 0.816, 0.821, 0.826, 0.831, 0.835, 0.84, 0.844, 0.848, 0.853, 0.857, 0.861, 0.864,
0.868, 0.872, 0.875, 0.879, 0.882, 0.885, 0.888, 0.891, 0.894, 0.897, 0.899, 0.902, 0.904, 0.906, 0.909, 0.911, 0.913, 0.914, 0.916, 0.918,
0.919, 0.921, 0.922, 0.924, 0.925, 0.926, 0.927, 0.928, 0.928, 0.929, 0.929, 0.93, 0.93, 0.93, 0.931, 0.931, 0.93, 0.93, 0.93, 0.93,
0.929, 0.929, 0.928, 0.927, 0.926, 0.925, 0.924, 0.923, 0.922, 0.92, 0.919, 0.917, 0.915, 0.913, 0.911, 0.909, 0.907, 0.905, 0.903, 0.9};

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_DFT)

                int note = coordinateLocal.y * AUDIOLINK_WIDTH + coordinateLocal.x;
                float4 last = GetSelfPixelData(coordinateGlobal);
                float2 amplitude = 0.;
                float phase = 0;
                float phaseDelta = pow(2, (note)/((float)AUDIOLINK_EXPBINS));
                phaseDelta = ((phaseDelta * AUDIOLINK_BOTTOM_FREQUENCY) / AUDIOLINK_SPS) * UNITY_TWO_PI * 2.; // 2 here because we're at 24kSPS                          
                phase = -phaseDelta * AUDIOLINK_SAMPHIST/2;     // Align phase so 0 phase is center of window.

                // DFT Window
                float halfWindowSize = AUDIOLINK_DFT_Q / (phaseDelta / UNITY_TWO_PI);
                int windowRange = floor(halfWindowSize) + 1;
                float totalWindow = 0;

                // For ??? reason, this is faster than doing a clever indexing which only searches the space that will be used.
                uint idx;
                for(idx = 0; idx < AUDIOLINK_SAMPHIST / 2; idx++)
                {
                    // XXX TODO: Try better windows, this is just a triangle.
                    float window = max(0, halfWindowSize - abs(idx - (AUDIOLINK_SAMPHIST / 2 - halfWindowSize)));
                    float af = GetSelfPixelData(ALPASS_WAVEFORM + uint2(idx % AUDIOLINK_WIDTH, idx / AUDIOLINK_WIDTH)).r;
                    
                    // Sin and cosine components to convolve.
                    float2 sinCos; sincos(phase, sinCos.x, sinCos.y);

                    // Step through, one sample at a time, multiplying the sin and cos values by the incoming signal.
                    amplitude += sinCos * af * window;
                    totalWindow += window;
                    phase += phaseDelta;
                }
                float mag = (length(amplitude) / totalWindow) * AUDIOLINK_BASE_AMPLITUDE * _Gain;

                // Treble compensation
                mag *= (lut[min(note, 239)] * AUDIOLINK_TREBLE_CORRECTION + 1);

                // Filtered output, also use FadeLength to lerp delay coefficient min/max for added smoothing effect
                float magFilt = lerp(mag, last.z, lerp(AUDIOLINK_DELAY_COEFFICIENT_MIN, AUDIOLINK_DELAY_COEFFICIENT_MAX, _FadeLength));

                // Filtered EQ'd output, used by AudioLink 4 Band
                float freqNormalized = note / float(AUDIOLINK_EXPOCT * AUDIOLINK_EXPBINS);
                float magEQ = magFilt * (((1.0 - freqNormalized) * _Bass) + (freqNormalized * _Treble));

                // Red:   Spectrum power, served straight up
                // Green: Filtered power EQ'd, used by AudioLink 4 Band
                // Blue:  Filtered spectrum
                return float4(mag, magEQ, magFilt, 1);
            }
            ENDCG
        }

        Pass
        {
            Name "Pass2WaveformData"
            CGPROGRAM
            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_WAVEFORM)

                // XXX Hack: Force the compiler to keep Samples0 and Samples1.
                if(guv.x < 0) return _Samples0[0] + _Samples1[0] + _Samples2[0] + _Samples3[0];   // slick, thanks @lox9973

                uint frame = coordinateLocal.x + coordinateLocal.y * AUDIOLINK_WIDTH;
                if(frame >= AUDIOLINK_SAMPHIST) frame = AUDIOLINK_SAMPHIST - 1;         //Prevent overflow.
                
                // Autogain
                float incomingGain = ((_AudioSource2D > 0.5) ? 1.f : 100.f);
                if(_EnableAutogain)
                {
                    float4 lastAutoGain = GetSelfPixelData(ALPASS_GENERALVU + int2(11, 0));

                    // Divide by the running volume.
                    incomingGain *= 1. / (lastAutoGain.x + _AutogainDerate);
                }

                // Downsampled to 24k and 12k samples per second by averaging, limiting frame to prevent overflow
                frame = min(frame, 2047);
                float downSample24 = (_AudioFrames[frame * 2] + _AudioFrames[frame * 2 + 1]) / 2.;
                frame = min(frame, 1023);
                float downSample12 = (_AudioFrames[frame * 4] + _AudioFrames[frame * 4 + 1] + _AudioFrames[frame * 4 + 2] + _AudioFrames[frame * 4 + 3]) / 4.;

                return float4(downSample24, _AudioFrames[frame], downSample12, 1) * incomingGain;
            }
            ENDCG
        }

        Pass
        {
            Name "Pass3AudioLink4Band"
            CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_AUDIOLINK)

                float audioBands[4] = {_X0, _X1, _X2, _X3};
                float audioThresholds[4] = {_Threshold0, _Threshold1, _Threshold2, _Threshold3};

                int band = min(coordinateLocal.y, 3);
                int delay = coordinateLocal.x;
                if (delay == 0) 
                {
                    // Get average of samples in the band
                    float total = 0.;
                    uint totalBins = AUDIOLINK_EXPBINS * AUDIOLINK_EXPOCT;
                    uint binStart = Remap(audioBands[band], 0., 1., AUDIOLINK_4BAND_FREQFLOOR * totalBins, AUDIOLINK_4BAND_FREQCEILING * totalBins);
                    uint binEnd = (band != 3) ? Remap(audioBands[band + 1], 0., 1., AUDIOLINK_4BAND_FREQFLOOR * totalBins, AUDIOLINK_4BAND_FREQCEILING * totalBins) : AUDIOLINK_4BAND_FREQCEILING * totalBins;
                    float threshold = audioThresholds[band];
                    for (uint i=binStart; i<binEnd; i++)
                    {
                        int2 spectrumCoord = int2(i % AUDIOLINK_WIDTH, i / AUDIOLINK_WIDTH);
                        float rawMagnitude = GetSelfPixelData(ALPASS_DFT + spectrumCoord).g;
                        total += rawMagnitude;
                    }
                    float magnitude = total / (binEnd - binStart);

                    // Log attenuation
                    magnitude = saturate(magnitude * (log(1.1) / (log(1.1 + pow(_LogAttenuation, 4) * (1.0 - magnitude))))) / pow(threshold, 2);

                    // Contrast
                    magnitude = saturate(magnitude * tan(1.57 * _ContrastSlope) + magnitude + _ContrastOffset * tan(1.57 * _ContrastSlope) - tan(1.57 * _ContrastSlope));

                    // Fade
                    float lastMagnitude = GetSelfPixelData(ALPASS_AUDIOLINK + int2(0, band)).g;
                    lastMagnitude -= -1.0 * pow(_FadeLength-1.0, 3);                                                                            // Inverse cubic remap
                    lastMagnitude = saturate(lastMagnitude * (1.0 + (pow(lastMagnitude - 1.0, 4.0) * _FadeExpFalloff) - _FadeExpFalloff));     // Exp falloff

                    magnitude = max(lastMagnitude, magnitude);

                    return float4(magnitude, magnitude, magnitude, 1.);

                // If part of the delay
                } else {
                    // Return pixel to the left
                    return GetSelfPixelData(ALPASS_AUDIOLINK + int2(coordinateLocal.x - 1, coordinateLocal.y));
                }
            }
            ENDCG
        }
        
        Pass
        {
            Name "Pass5-VU-Meter-And-Other-Info"
            CGPROGRAM
            // The structure of the output is:
            // RED CHANNEL: Peak Amplitude
            // GREEN CHANNEL: RMS Amplitude.
            // BLUE CHANNEL: RESERVED.

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_GENERALVU)

                float total = 0;
                float peak = 0;
                
                // Only VU over 768 12kSPS samples
                uint i;
                for( i = 0; i < 768; i++ )
                {
                    float audioFrame = GetSelfPixelData(ALPASS_WAVEFORM + uint2(i % AUDIOLINK_WIDTH, i / AUDIOLINK_WIDTH)).b;
                    total += audioFrame * audioFrame;
                    peak = max(peak, abs(audioFrame));
                }

                float peakRMS = sqrt(total / i);
                float4 markerValue = GetSelfPixelData(ALPASS_GENERALVU + int2(9, 0));
                float4 markerTimes = GetSelfPixelData(ALPASS_GENERALVU + int2(10, 0));
                float4 lastAutogain = GetSelfPixelData(ALPASS_GENERALVU + int2(11, 0));
                float time = _Time.y;
                
                if(time - markerTimes.x > 1.0) markerValue.x = -1;
                if(time - markerTimes.y > 1.0) markerValue.y = -1;
                
                if(markerValue.x < peakRMS)
                {
                    markerValue.x = peakRMS;
                    markerTimes.x = time;
                }

                if(markerValue.y < peak)
                {
                    markerValue.y = peak;
                    markerTimes.y = time;
                }

                if(coordinateLocal.x >= 8)
                {
                    if(coordinateLocal.x == 8)
                    {
                        // First pixel: Current value.
                        return float4(peakRMS, peak, 0, 1.);
                    }
                    else if(coordinateLocal.x == 9)
                    {
                        // Second pixel: Limit Output
                        return markerValue;
                    }
                    else if(coordinateLocal.x == 10)
                    {
                        // Second pixel: Limit time
                        return markerTimes;
                    }
                    else if(coordinateLocal.x == 11)
                    {
                        // Third pixel: Auto Gain / Volume Monitor for ColorChord
                        
                        // Compensate for the fact that we've already gain'd our samples.
                        float deratePeak = peak / (lastAutogain.x + _AutogainDerate);
                        
                        if(deratePeak > lastAutogain.x)
                        {
                            lastAutogain.x = lerp(deratePeak, lastAutogain.x, .5); //Make attack quick
                        }
                        else
                        {
                            lastAutogain.x = lerp(deratePeak, lastAutogain.x, .995); //Make decay long.
                        }
                        
                        lastAutogain.y = lerp(peak, lastAutogain.y, 0.95);
                        return lastAutogain;
                    }
                }
                else
                {
                    if(coordinateLocal.x == 0)
                    {
                        // Pixel 0 = Version
                        return _VersionNumberAndFPSProperty;
                    }
                    else if(coordinateLocal.x == 1)
                    {
                        // Pixel 1 = Frame Count, if we did not repeat, this would stop counting after ~51 hours.
                        // Note: This is also used to measure FPS.
                        
                        float4 lastVal = GetSelfPixelData(ALPASS_GENERALVU + int2(1, 0));
                        float frameCount = lastVal.r;
                        float frameCountFPS = lastVal.g;
                        float frameCountLastFPS = lastVal.b;
                        float lastTimeFPS = lastVal.a;
                        frameCount++;
                        if(frameCount >= 7776000) //~24 hours.
                            frameCount = 0;
                        frameCountFPS++;

                        // See if we've been reset.
                        if(lastTimeFPS > _Time.y)
                        {
                            lastTimeFPS = 0;
                        }

                        // After one second, take the running FPS and present it as the now FPS.
                        if(_Time.y > lastTimeFPS + 1)
                        {
                            frameCountLastFPS = frameCountFPS;
                            frameCountFPS = 0;
                            lastTimeFPS = _Time.y;
                        }
                        return float4(frameCount, frameCountFPS, frameCountLastFPS, lastTimeFPS);
                    }
                    else if(coordinateLocal.x == 2)
                    {
                        // Output of this is daytime, in milliseconds
                        // as an int.  But, we only have half4's.
                        // so we have to get creative.

                        //_AdvancedTimeProps.x = seconds % 1024
                        //_AdvancedTimeProps.y = seconds / 1024

                        // This is done a little awkwardly as to prevent any overflows.
                        uint dtms = _AdvancedTimeProps.x * 1000;
                        uint dtms2 = _AdvancedTimeProps.y * 1000 + (dtms >> 10);
                        return float4(
                            (float)(dtms & 0x3ff),
                            (float)((dtms2) & 0x3ff),
                            (float)((dtms2 >> 10) & 0x3ff),
                            (float)((dtms2 >> 20) & 0x3ff)
                            );
                    }
                    else if(coordinateLocal.x == 3)
                    {
                        int ftpa = _AdvancedTimeProps.z * 1000.;
                        return float4(ftpa & 0x3ff, (ftpa >> 10) & 0x3ff, (ftpa >> 20), 0);
                    }
                    else if(coordinateLocal.x == 4)
                    {
                        return float4(0, 0, 0, 0);
                    }
                }

                // Reserved
                return 0;
            }
            ENDCG
        }

        Pass
        {
            Name "Pass6ColorChord-Notes"
            CGPROGRAM
            
            float NoteWrap(float note1, float note2)
            {
                float diff = note2 - note1;
                diff = glsl_mod(diff, AUDIOLINK_EXPBINS);
                if(diff > AUDIOLINK_EXPBINS / 2)
                    return diff - AUDIOLINK_EXPBINS;
                else
                    return diff;
            }
            
            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_CCINTERNAL)
                
                float vuAmplitude = GetSelfPixelData(ALPASS_GENERALVU + int2(8, 0)).y * _Gain;
                float noteMinimum = 0.00 + 0.1 * vuAmplitude;

                //Note structure:
                // .x = Note frequency (0...AUDIOLINK_ETOTALBINS, but floating point)
                // .y = The incoming intensity.
                // .z = Lagged intensity.         ---> This is what decides if a note is going to disappear.
                // .w = Quicker lagged intensity.
                
                //NoteB Structure
                // .x = Note Number  ::: NOTE if .y < 0 this is the index of where this note _went_ or what note it was joined to.
                // .y = Time this note has existed.
                // .z = Sorted-by-frequency position. (With note 0 being the 0th note)
                
                //Summary:
                // .x = Total number of notes.
                // .y .z .w = sum of note's yzw.
                
                //SummaryB:
                // .x = Latest note number.
                // .y = AUDIOLINK_ROOTNOTE
                // .z = number of populated notes.
                
                float4 notes[COLORCHORD_MAX_NOTES];
                float4 notesB[COLORCHORD_MAX_NOTES];

                uint i;
                for(i = 0; i < COLORCHORD_MAX_NOTES; i++)
                {
                    notes[i] = GetSelfPixelData(ALPASS_CCINTERNAL + uint2(i + 1, 0)) * float4(1, 0, 1, 1);
                    notesB[i] = GetSelfPixelData(ALPASS_CCINTERNAL + uint2(i + 1, 1));
                }

                float4 noteSummary = GetSelfPixelData(ALPASS_CCINTERNAL);
                float4 noteSummaryB = GetSelfPixelData(ALPASS_CCINTERNAL + int2(0, 1));
                float lastAmplitude = GetSelfPixelData(ALPASS_DFT + uint2(AUDIOLINK_EXPBINS, 0)).b;
                float thisAmplitude = GetSelfPixelData(ALPASS_DFT + uint2(1 + AUDIOLINK_EXPBINS, 0)).b;

                for(i = AUDIOLINK_EXPBINS + 2; i < COLORCHORD_EMAXBIN; i++)
                {
                    float nextAmplitude = GetSelfPixelData(ALPASS_DFT + uint2(i % AUDIOLINK_WIDTH, i / AUDIOLINK_WIDTH)).b;
                    if(thisAmplitude > lastAmplitude && thisAmplitude > nextAmplitude && thisAmplitude > noteMinimum)
                    {
                        // Find actual peak by looking ahead and behind.
                        float diffA = thisAmplitude - nextAmplitude;
                        float diffB = thisAmplitude - lastAmplitude;
                        float noteFreq = glsl_mod(i - 1, AUDIOLINK_EXPBINS);
                        if(diffA < diffB)
                        {
                            // Behind
                            noteFreq -= 1. - diffA / diffB; //Ratio must be between 0 .. 0.5
                        }
                        else
                        {
                            // Ahead
                            noteFreq += 1. - diffB / diffA;
                        }

                        uint j;
                        int closestNote = -1;
                        int freeNote = -1;
                        float closestNoteDistance = COLORCHORD_NOTE_CLOSEST;
                                                
                        // Search notes to see what the closest note to this peak is.
                        // also look for any empty notes.
                        for(j = 0; j < COLORCHORD_MAX_NOTES; j++)
                        {
                            float dist = abs(NoteWrap(notes[j].x, noteFreq));
                            if(notes[j].z <= 0)
                            {
                                if(freeNote == -1)
                                    freeNote = j;
                            }
                            else if(dist < closestNoteDistance)
                            {
                                closestNoteDistance = dist;
                                closestNote = j;
                            }
                        }
                        
                        float thisIntensity = thisAmplitude * COLORCHORD_NEW_NOTE_GAIN;
                        
                        if(closestNote != -1)
                        {
                            // Note to combine peak to has been found, roll note in.
                            float4 n = notes[closestNote];
                            float drag = NoteWrap(n.x, noteFreq) * 0.05;

                            float mn = max(n.y, thisAmplitude * COLORCHORD_NEW_NOTE_GAIN)
                                // Technically the above is incorrect without the below, additional notes found should contribute.
                                // But I'm finding it looks better w/o it.  Well, the 0.3 is arbitrary.  But, it isn't right to
                                // only take max.
                                + thisAmplitude * COLORCHORD_NEW_NOTE_GAIN * 0.3;

                            notes[closestNote] = float4(n.x + drag, mn, n.z, n.a);
                        }
                        else if(freeNote != -1)
                        {

                            int jc = 0;
                            int ji = 0;
                            // uuuggghhhh Ok, so this's is probably just me being paranoid
                            // but I really wanted to make sure all note IDs are unique
                            // in case another tool would care about the uniqueness.
                            [loop]
                            for(ji = 0; ji < COLORCHORD_MAX_NOTES && jc != COLORCHORD_MAX_NOTES; ji++)
                            {
                                noteSummaryB.x = noteSummaryB.x + 1;
                                if(noteSummaryB.x > 1023) noteSummaryB.x = 0;
                                [loop]
                                for(jc = 0; jc < COLORCHORD_MAX_NOTES; jc++)
                                {
                                    if(notesB[jc].x == noteSummaryB.x)
                                        break;
                                }
                            }

                            // Couldn't find note.  Create a new note.
                            notes[freeNote]  = float4(noteFreq, thisIntensity, thisIntensity, thisIntensity);
                            notesB[freeNote] = float4(noteSummaryB.x, unity_DeltaTime.x, 0, 0);
                        }
                        else
                        {
                            // Whelp, the note fell off the wagon.  Oh well!
                        }
                    }
                    lastAmplitude = thisAmplitude;
                    thisAmplitude = nextAmplitude;
                }

                float4 newNoteSummary = 0.;
                float4 newNoteSummaryB = noteSummaryB;
                newNoteSummaryB.y = AUDIOLINK_ROOTNOTE;

                [loop]
                for(i = 0; i < COLORCHORD_MAX_NOTES; i++)
                {
                    uint j;
                    float4 n1 = notes[i];
                    float4 n1B = notesB[i];
                    
                    [loop]
                    for(j = 0; j < COLORCHORD_MAX_NOTES; j++)
                    {
                        // 🤮 Shader compiler can't do triangular loops.
                        // We don't want to iterate over a cube just compare ith and jth note once.

                        float4 n2 = notes[j];

                        if(n2.z > 0 && j > i && n1.z > 0)
                        {
                            // Potentially combine notes
                            float dist = abs(NoteWrap(n1.x, n2.x));
                            if(dist < COLORCHORD_NOTE_CLOSEST)
                            {
                                //Found combination of notes.  Nil out second.
                                float drag = NoteWrap(n1.x, n2.x) * 0.5;//n1.z/(n2.z+n1.y);
                                n1 = float4(n1.x + drag, n1.y + thisAmplitude, n1.z, n1.a);

                                //n1B unchanged.

                                notes[j] = 0;
                                notesB[j] = float4(i, -1, 0, 0);
                            }
                        }
                    }
                    
                    // Filter n1.z from n1.y.
                    if(n1.z >= 0)
                    {
                        // Make sure we're wrapped correctly.
                        n1.x = glsl_mod(n1.x, AUDIOLINK_EXPBINS);
                        
                        // Apply filtering
                        n1.z = lerp(n1.y, n1.z, COLORCHORD_IIR_DECAY_1) - COLORCHORD_CONSTANT_DECAY_1; //Make decay slow.
                        n1.w = lerp(n1.y, n1.w, COLORCHORD_IIR_DECAY_2) - COLORCHORD_CONSTANT_DECAY_2; //Make decay slow.

                        n1B.y += unity_DeltaTime.x;


                        if(n1.z < noteMinimum)
                        {
                            n1 = -1;
                            n1B = 0;
                        }
                        //XXX TODO: Do uniformity calculation on n1 for n1.a.
                    }

                    if(n1.z >= 0)
                    {
                        // Compute Y to create a "unified" value.  This is good for understanding
                        // the ratio of how "important" this note is.
                        n1.y = pow(max(n1.z - noteMinimum*10, 0), 1.5);
                    
                        newNoteSummary += float4(1., n1.y, n1.z, n1.w);
                    }
                    
                    notes[i] = n1;
                    notesB[i] = n1B;
                }

                // Sort by frequency and count notes.
                // These loops are phrased funny because the unity shader compiler gets really
                // confused easily.
                float sortedNoteSlotValue = -1000;
                newNoteSummaryB.z = 0;

                [loop]
                for(i = 0; i < COLORCHORD_MAX_NOTES; i++)
                {
                    //Count notes
                    newNoteSummaryB.z += (notes[i].z > 0) ? 1 : 0;

                    float closestToSlotWithoutGoingOver = 100;
                    int sortID = -1;
                    int j;
                    for(j = 0; j < COLORCHORD_MAX_NOTES; j++)
                    {
                        float4 n2 = notes[j];
                        float noteFreqB = glsl_mod(-notes[0].x + 0.5 + n2.x , AUDIOLINK_EXPBINS);
                        if(n2.z > 0 && noteFreqB > sortedNoteSlotValue && noteFreqB < closestToSlotWithoutGoingOver)
                        {
                            closestToSlotWithoutGoingOver = noteFreqB;
                            sortID = j;
                        }
                    }
                    sortedNoteSlotValue = closestToSlotWithoutGoingOver;
                    notesB[i] = notesB[i] * float4(1, 1, 0, 1) + float4(0, 0, sortID, 0);
                }

                // We now have a condensed list of all notes that are playing.
                if( coordinateLocal.x == 0 )
                {
                    // Summary note.
                    return (coordinateLocal.y) ? newNoteSummaryB : newNoteSummary;
                }
                else
                {
                    // Actual Note Data
                    return (coordinateLocal.y) ? notesB[coordinateLocal.x - 1] : notes[coordinateLocal.x - 1];
                }
            }
            ENDCG
        }

        Pass
        {
            Name "Pass7-AutoCorrelator"
            CGPROGRAM

            #define AUTOCORRELATOR_EMAXBIN 120
            #define AUTOCORRELATOR_EBASEBIN 0

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_AUTOCORRELATOR)

                float wavePosition = (float)coordinateLocal.x;
                float2 fvTotal = 0;
                float fvr = 15.;

                // This computes both the regular autocorrelator in the R channel
                // as well as a uncorrelated autocorrelator in the G channel
                uint i;
                for(i = AUTOCORRELATOR_EBASEBIN; i < AUTOCORRELATOR_EMAXBIN; i++)
                {
                    float bin = GetSelfPixelData(ALPASS_DFT + uint2(i % AUDIOLINK_WIDTH, i / AUDIOLINK_WIDTH)).b;
                    float frequency = pow(2, i / 24.) * AUDIOLINK_BOTTOM_FREQUENCY / AUDIOLINK_SPS * UNITY_TWO_PI;
                    float2 csv = float2(cos(frequency * wavePosition * fvr),  cos(frequency * wavePosition * fvr + i * 0.32));
                    csv.g *= step(i % 4, 1) * 4.;
                    fvTotal += csv * (bin * bin);
                }

                // Red:   Regular autocorrelator
                // Green: Uncorrelated autocorrelator
                // Blue:  Reserved
                return float4(fvTotal, 0, 1);
            }
            ENDCG
        }

        Pass
        {
            Name "Pass8-ColorChord-Linear"
            CGPROGRAM
            
            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_CCSTRIP)

                int p;
                
                const float Brightness = .3;
                const float RootNote = 0;
                
                float4 NotesSummary = GetSelfPixelData(ALPASS_CCINTERNAL);

                float TotalPower = 0.0;
                TotalPower = NotesSummary.y;

                float PowerPlace = 0.0;
                for(p = 0; p < COLORCHORD_MAX_NOTES; p++)
                {
                    float4 NotesB = GetSelfPixelData(ALPASS_CCINTERNAL + int2(1 + p, 1));
                    float4 Peak = GetSelfPixelData(ALPASS_CCINTERNAL + int2(1 + NotesB.z, 0));
                    if(Peak.y <= 0) continue;

                    float Power = Peak.y/TotalPower;
                    PowerPlace += Power;
                    if(PowerPlace >= IN.globalTexcoord.x) 
                    {
                        return float4(CCtoRGB(Peak.x, Peak.a*Brightness, AUDIOLINK_ROOTNOTE), 1.0);
                    }
                }
                
                return float4(0., 0., 0., 1.);
            }
            ENDCG
        }
        
        Pass
        {
            Name "Pass9-ColorChord-Lights"
            CGPROGRAM

            static const float _PickNewSpeed = 1.0;
            
            float tinyrand(float3 uvw)
            {
                return frac(cos(dot(uvw, float3(137.945, 942.32, 593.46))) * 442.5662);
            }

            float SetNewCellValue(float a)
            {
                return a*.5;
            }

            float4 frag(v2f_customrendertexture IN) : SV_Target
            {
                AUDIO_LINK_ALPHA_START(ALPASS_CCLIGHTS)
                
                float4 NotesSummary = GetSelfPixelData(ALPASS_CCINTERNAL);
                
                #define NOTESUFFIX(n) n.y       //was pow(n.z, 1.5)
                
                float4 ComputeCell = GetSelfPixelData(ALPASS_CCLIGHTS + int2(coordinateLocal.x, 1));
                //ComputeCell
                //    .x = Mated Cell # (Or -1 for black)
                //    .y = Minimum Brightness Before Jump
                //    .z = ???
                
                float4 ThisNote = GetSelfPixelData(ALPASS_CCINTERNAL + int2(ComputeCell.x + 1, 0));
                //  Each element:
                //   R: Peak Location (Note #)
                //   G: Peak Intensity
                //   B: Calm Intensity
                //   A: Other Intensity
                
                ComputeCell.y -= _PickNewSpeed * 0.01;

                if(NOTESUFFIX(ThisNote) < ComputeCell.y || ComputeCell.y <= 0 || ThisNote.z < 0)
                {
                    //Need to select new cell.
                    float min_to_acquire = tinyrand(float3(coordinateLocal.xy, _Time.x));
                    
                    int n;
                    float4 SelectedNote = 0.;
                    int SelectedNoteNo = -1;
                    
                    float cumulative = 0.0;
                    for(n = 0; n < COLORCHORD_MAX_NOTES; n++)
                    {
                        float4 Note = GetSelfPixelData(ALPASS_CCINTERNAL + int2(n + 1, 0));
                        float unic = NOTESUFFIX(Note);
                        if(unic > 0)
                            cumulative += unic;
                    }

                    float sofar = 0.0;
                    for(n = 0; n < COLORCHORD_MAX_NOTES; n++)
                    {
                        float4 Note = GetSelfPixelData(ALPASS_CCINTERNAL + int2(n + 1, 0));
                        float unic = NOTESUFFIX(Note);
                        if( unic > 0 ) 
                        {
                            sofar += unic;
                            if(sofar/cumulative > min_to_acquire)
                            {
                                SelectedNote = Note;
                                SelectedNoteNo = n;
                                break;
                            }
                        }
                    }
                
                    if(SelectedNote.z > 0.0)
                    {
                        ComputeCell.x = SelectedNoteNo;
                        ComputeCell.y = SetNewCellValue(NOTESUFFIX(SelectedNote));
                    }
                    else
                    {
                        ComputeCell.x = 0;
                        ComputeCell.y = 0;
                    }
                }
                
                ThisNote = GetSelfPixelData(ALPASS_CCINTERNAL + int2(ComputeCell.x + 1, 0));

                if(coordinateLocal.y < 0.5)
                {
                    // the light color output
                    if(ComputeCell.y <= 0)
                    {
                        return 0.;
                    }
                    
                    //XXX TODO: REVISIT THIS!! Ths is an arbitrary value!
                    float intensity = ThisNote.a/3;
                    return float4(CCtoRGB(glsl_mod(ThisNote.x,48.0 ),intensity, AUDIOLINK_ROOTNOTE), 1.0);
                }
                else
                {
                    // the compute output
                    return ComputeCell;
                }
            }
            ENDCG
        }

        Pass 
        {
            Name "No-op"
            ColorMask 0
            ZWrite Off 
        }
    }
}
