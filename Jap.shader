Shader "Unlit/Jap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _HeadPos("Head Pos",Vector) = (0.0,0.05,0.07,0)
        _HeadScale("Head Scale",Vector) = (0.8,0.75,0.85,0)

        _JawPos1("Jaw Pos 1",Vector) = (0.0,-0.38,0.35)
        _JawPos2("Jaw Pos 2",Vector) = (0,-0.17,0.16)

        _JawRot1("Jaw Rot 1",float) = 0.4
        _JawRot2("Jaw Rot 2",float) = 0.1

        _JawBaseScale("Jaw Base Scale",Vector) = (0.66,0.43,0.50)
        _HeadJawSMin("Head Jaw SMin",float) = 0.19

        AA("AA", float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent+1" }
        LOD 100

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off
            ZTest Always
            
            CGPROGRAM
            //#pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Jap_Common.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float4 vertex : SV_POSITION;
            };

            float AA;

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float3 cur_cameraRight;
            float3 cur_cameraForward;
            float3 cur_cameraUp;
            float  cur_camFocalLen;

            float4x4 _JawTransform;

            float4 _HeadPos;
            float4 _HeadScale;
            float4 _RayOrigin;
            float4 _RayTarget;
            float  _HeadJawSMin;
            float3 _JawPos1;
            float3 _JawPos2;
            float _JawRot1;
            float _JawRot2;
            float3 _JawBaseScale;

            float3 animData; // { blink, nose follow up, mouth } 
            float3 animHead; // { head rotation angles }

            struct VertexPositionInputs
            {
                float3 positionWS; // World space position
                float3 positionVS; // View space position
                float4 positionCS; // Homogeneous clip space position
                float4 positionNDC;// Homogeneous normalized device coordinates
            };

            float4x4 GetObjectToWorldMatrix()
            {
                return UNITY_MATRIX_M;
            }

            float4x4 GetWorldToViewMatrix()
            {
                return UNITY_MATRIX_V;
            }

            // Transform to homogenous clip space
            float4x4 GetWorldToHClipMatrix()
            {
                return UNITY_MATRIX_VP;
            }

            float3 TransformObjectToWorld(float3 positionOS)
            {
                return mul(GetObjectToWorldMatrix(), float4(positionOS, 1.0)).xyz;
            }

            float3 TransformWorldToView(float3 positionWS)
            {
                return mul(GetWorldToViewMatrix(), float4(positionWS, 1.0)).xyz;
            }

            // Tranforms position from world space to homogenous space
            float4 TransformWorldToHClip(float3 positionWS)
            {
                return mul(GetWorldToHClipMatrix(), float4(positionWS, 1.0));
            }
            
            VertexPositionInputs GetVertexPositionInputs(float3 positionOS)
            {
                VertexPositionInputs input;
                input.positionWS = TransformObjectToWorld(positionOS);
                input.positionVS = TransformWorldToView(input.positionWS);
                input.positionCS = TransformWorldToHClip(input.positionWS);
    
                float4 ndc = input.positionCS * 0.5f;
                input.positionNDC.xy = float2(ndc.x, ndc.y * _ProjectionParams.x) + ndc.w;
                input.positionNDC.zw = input.positionCS.zw;
        
                return input;
            }

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex.x = v.vertex.x*2.0;
                o.vertex.y = v.vertex.y*2.0;
                o.vertex.z = 1.0;
                o.vertex.w = 1.0;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos = ComputeScreenPos(o.vertex);
                 return o;
            }

            float3x3 calcCamera( in float time, out float3 oRo, out float oFl )
            {                
                oRo = _WorldSpaceCameraPos;
                oFl = cur_camFocalLen;
                return float3x3(normalize(cur_cameraRight),normalize(cur_cameraUp),normalize(cur_cameraForward));
            }

            float4 map( in float3 pos, in float time, out float outMat, out float3 uvw )
            {
                outMat = 1.0;

                float3 oriPos = pos;
            
                // head deformation and transformation
                //pos.y /= 1.04;
                float3 opos = 0;
                //opos = moveHead( pos, animHead, smoothstep(-1.2, 0.2,pos.y) );
                //pos  = moveHead( pos, animHead, smoothstep(-1.4,-1.0,pos.y) );
                //pos.x *= 1.04;
                //pos.y /= 1.02;
                uvw = pos;

                // symmetric coord systems (sharp, and smooth)
                float3 qos = float3(abs(pos.x),pos.yz);
                float3 sos = float3(sqrt(qos.x*qos.x+0.0005),pos.yz);
                
                float3 headPos = mul(unity_ObjectToWorld,float4(_HeadPos.xyz,1));
                float d = sdEllipsoid( pos-headPos, _HeadScale.xyz );

                float3 jaw_pos1 = mul(unity_ObjectToWorld,float4(_JawPos1.xyz,1));
                float3 jaw_pos2 = mul(unity_ObjectToWorld,float4(_JawPos2.xyz,1));
                jaw_pos2 = _JawPos2.xyz;

                // jaw
                float3 pos_for_jaw = mul(_JawTransform,float4(pos,1));

                float3 mos = pos-jaw_pos1; 
                mos.yz = rot(mos.yz,_JawRot1);
                //mos += jaw_pos1;
                //mos.yz = rot(mos.yz,_JawRot2/**animData.z*/);

                float3 jawScale = _JawBaseScale + 
                float3(sclamp(mos.y*0.9-0.1*mos.z,-0.3,0.4),
                sclamp(mos.y*0.5,-0.5,0.2),
                sclamp(mos.y*0.3,-0.45,0.5));

                jawScale = _JawBaseScale;

                float d2 = sdEllipsoid(pos_for_jaw,jawScale);
                // float3(
                // _JawBaseScale.x+sclamp(mos.y*0.9-0.1*mos.z,-0.3,0.4),
                // _JawBaseScale.y+sclamp(mos.y*0.5,-0.5,0.2),
                // _JawBaseScale.z+sclamp(mos.y*0.3,-0.45,0.5)));

                d = smin(d,d2,_HeadJawSMin);
                float4 res = float4( d2, 0, 0, 0 );
                return res;          
            }

            float4 mapD( in float3 pos, in float time )
            {
                float matID;
                float3 uvw;
                float4 h = map(pos, time, matID, uvw);
            
                if( matID<1.5 ) // skin
                {
                    // pores
                    float d = 0;
                    h.x += 0.0015*d*d;
                }
                else if( matID>3.5 && matID<4.5 ) // hair
                {
                    // some random displacement to evoke hairs
                    float te = 0;
                    h.x -= 0.02*te;
                }    
                return h;
            }

            float3 calcNormal( in float3 pos, in float time )
            {
                const float eps = 0.001;
            #if 0    
                float2 e = float2(1.0,-1.0)*0.5773;
                return normalize( e.xyy*map( pos + e.xyy*eps,time,kk ).x + 
                e.yyx*map( pos + e.yyx*eps,time,kk ).x + 
                e.yxy*map( pos + e.yxy*eps,time,kk ).x + 
                e.xxx*map( pos + e.xxx*eps,time,kk ).x );
            #else
                float4 n = float4(0,0,0,0);
                for( int i=0; i<4; i++ )
                {
                    float4 s = float4(pos, 0.0);
                    float kk; float3 kk2;
                    s[i] += eps;
                    n[i] = mapD(s.xyz, time).x;
                    //if( n.x+n.y+n.z+n.w>100.0 ) break;
                }
                return normalize(n.xyz-n.w);
            #endif   
            }

            float calcSoftshadow( in float3 ro, in float3 rd, in float mint, in float tmax, in float time, float k )
            {
                // first things first - let's do a bounding volume test
                float2 sph = iCylinderY( ro, rd, 1.5 );
                //float2 sph = iConeY(ro-float3(-0.05,3.7,0.35),rd,0.08);
                tmax = min(tmax,sph.y);

                // raymarch and track penumbra    
                float res = 1.0;
                float t = mint;
                for( int i=0; i<128; i++ )
                {
                    float kk; float3 kk2;
                    float h = map( ro + rd*t, time, kk, kk2 ).x;
                    res = min( res, k*h/t );
                    t += clamp( h, 0.005, 0.1 );
                    if( res<0.002 || t>tmax ) break;
                }
                return max( res, 0.0 );
            }

            float calcOcclusion( in float3 pos, in float3 nor, in float time )
            {
                const float X4 = 1.1673039782614187; 
                const float4 H4 = float4(  1.0/X4, 1.0/(X4*X4), 1.0/(X4*X4*X4), 1.0/(X4*X4*X4*X4) );
                float kk; float3 kk2;
                float ao = 0.0;
                //float off = textureLod(iChannel3,gl_FragCoord.xy/256.0,0.0).x;
                float off = 0;
                float4 k = float4(0.7012912,0.3941462,0.8294585,0.109841)+off;
                for( int i=ZERO; i<16; i++ )
                {
                    k = frac(k + H4);
                    float3 ap = normalize(-1.0+2.0*k.xyz);
                    float h = k.w*0.1;
                    ap = (nor+ap)*h;
                    float d = map( pos+ap, time, kk, kk2 ).x;
                    ao += max(0.0,h-d);
                    if( ao>16.0 ) break;
                }
                ao /= 16.0;
                return clamp( 1.0-ao*24.0, 0.0, 1.0 );
            }

            float2 intersect( in float3 ro, in float3 rd, in float tmax, in float time, out float3 cma, out float3 uvw )
            {
                cma = float3(0,0,0);
                uvw = float3(0,0,0);
                float matID = -1.0;

                float t = 1.0;

                // bounding volume test first
                //float2 sph = iCylinderY( ro, rd, 1.5 );
                //float2 sph = iConeY(ro-float3(-0.05,3.7,0.35),rd,0.08);
            
                //if( sph.y<0.0 ) 
                //{
                //    return float2(-1.0,-1.0);
                //}                
            
                // clip raymarch space to bonding volume
                //tmax = min(tmax,sph.y);
                //t    = max(1.0, sph.x);
                tmax = 100;
                t = 1;
            
                // raymarch
                for( int i=0; i<256; i++ )
                {
                    float3 pos = ro + t*rd;

                    float tmp;
                    float4 h = map(pos,time,tmp,uvw);
                    if( h.x<0.001 )
                    {
                        cma = h.yzw;
                        matID = tmp;
                        break;
                    }
                    t += h.x*0.95;
                    if( t>tmax ) break;
                }
                return float2(t,matID);
            }

            float animEye( in float time )
            {
                const float w = 6.1;
                float t = mod(time-0.31,w*1.0);
            
                float q = frac((time-0.31)/(2.0*w));
                float s = (q > 0.5) ? 1.0 : 0.0;
                return (t<0.15)?1.0-s:s;
            }

            float4 renderJap( in float2 p, in float3 ro, in float3 rd, in float tmax, in float3 col, in float time )
            { 
                float3 cma, uvw;
                float2 tm = intersect( ro, rd, tmax, time, cma, uvw );

                float out_alpha = 0;

                // --------------------------
                // shading/lighting	
                // --------------------------
                if( tm.y>0.0 )
                {   
                    //return float4(1,1,1,0.1);
                    out_alpha = 1;
                    float3 pos = ro + tm.x*rd;
                    float3 nor = calcNormal(pos, time);

                    float ks = 1.0;
                    float se = 16.0;
                    float tinterShadow = 0.0;
                    float sss = 0.0;
                    float focc = 1.0;
                    //float frsha = 1.0;

                    // --------------------------
                    // material
                    // --------------------------
                    if( tm.y<1.5 ) // skin
                    {
                        float3 qos = float3(abs(uvw.x),uvw.yz);

                        // base skin color
                        col = lerp(float3(0.225,0.15,0.12),
                        float3(0.24,0.1,0.066),
                        smoothstep(0.4 ,0.0,length( qos.xy-float2(0.42,-0.3)))+
                        smoothstep(0.15,0.0,length((qos.xy-float2(0,-0.29))/float2(1.4,1))));
                  
                        // fix that ugly highlight
                        col -= 0.03*smoothstep(0.13,0.0,length((qos.xy-float2(0,-0.49))/float2(2,1)));
                  
                        // lips
                        //col = lerp(col,float3(0.14,0.06,0.1),cma.x*step(-0.7,qos.y));
                  
                        // eyelashes
                        //col = lerp(col,float3(0.04,0.02,0.02)*0.6,0.9*cma.y);

                        // fake skin drag
                        uvw.y += 0.025*animData.x*smoothstep(0.3,0.1,length(uvw-float3(0.0,0.1,1.0)));
                        uvw.y -= 0.005*animData.y*smoothstep(0.09,0.0,abs(length((uvw.xy-float2(0.0,-0.38))/float2(2.5,1.0))-0.12));
                  
                        // freckles
                        float2 ti = floor(9.0+uvw.xy/0.04);
                        float2 uv = frac(uvw.xy/0.04)-0.5;
                        float te = frac(111.0*sin(1111.0*ti.x+1331.0*ti.y));
                        te = smoothstep(0.9,1.0,te)*exp(-dot(uv,uv)*24.0); 
                        //col *= lerp(float3(1.1,1.1,1.1),float3(0.8,0.6,0.4), te);

                        // texture for specular
                        //ks = 0.5 + 4.0*texture(iChannel3,uvw.xy*1.1).x;
                        ks = 0;
                        se = 12.0;
                        ks *= 0.5;
                        tinterShadow = 1.0;
                        sss = 1.0;
                        ks *= 1.0 + cma.x;
                  
                        // black top
                        //col *= 1.0-smoothstep(0.48,0.51,uvw.y);
                  
                        // makeup
                        float d2 = sdEllipsoid(qos-float3(0.25,-0.03,0.43),float3(0.37,0.42,0.4));
                        //col = lerp(col,float3(0.06,0.024,0.06),1.0 - smoothstep(0.0,0.03,d2));

                        // eyebrows
                        {
                            #if 0
                            // youtube video version
                            float4 be = sdBezier( qos, float3(0.165+0.01*animData.x,0.105-0.02*animData.x,0.89),
                            float3(0.37,0.18-0.005*animData.x,0.82+0.005*animData.x), 
                            float3(0.53,0.15,0.69) );
                            float ra = 0.005 + 0.015*sqrt(be.y);
                            #else
                            // fixed version
                            float4 be = sdBezier( qos, float3(0.16+0.01*animData.x,0.11-0.02*animData.x,0.89),
                            float3(0.37,0.18-0.005*animData.x,0.82+0.005*animData.x), 
                            float3(0.53,0.15,0.69) );
                            float ra = 0.005 + 0.01*sqrt(1.0-be.y);
                            #endif
                            float dd = 1.0+0.05*(0.7*sin((sin(qos.x*3.0)/3.0-0.5*qos.y)*350.0)+
                            0.3*sin((qos.x-0.8*qos.y)*250.0+1.0));
                            float d = be.x - ra*dd;
                            float mask = 1.0-smoothstep(-0.005,0.01,d);
                            //col = lerp(col,float3(0.04,0.02,0.02),mask*dd );
                        }

                        // fake occlusion
                        focc = 0.2+0.8*pow(1.0-smoothstep(-0.4,1.0,uvw.y),2.0);
                        focc *= 0.5+0.5*smoothstep(-1.5,-0.75,uvw.y);
                        focc *= 1.0-smoothstep(0.4,0.75,abs(uvw.x));
                        focc *= 1.0-0.4*smoothstep(0.2,0.5,uvw.y);
                  
                        focc *= 1.0-smoothstep(1.0,1.3,1.7*uvw.y-uvw.x);
                  
                        //frsha = 0.0;
                    }
                    else if( tm.y<2.5 ) // eye
                    {
                        // The eyes are fake in that they aren't 3D. Instead I simply
                        // stamp a 2D mathematical drawing of an iris and pupil. That
                        // includes the highlight and occlusion in the eyesballs.
                  
                        sss = 1.0;

                        float3 qos = float3(abs(uvw.x),uvw.yz);
                        float ss = sign(uvw.x);
                  
                        // iris animation
                        float dt = floor(time*1.1);
                        float ft = frac(time*1.1);
                        float2 da0 = sin(1.7*(dt+0.0)) + sin(2.3*(dt+0.0)+float2(1.0,2.0));
                        float2 da1 = sin(1.7*(dt+1.0)) + sin(2.3*(dt+1.0)+float2(1.0,2.0));
                        float2 da = lerp(da0,da1,smoothstep(0.9,1.0,ft));

                        float gg = animEye(time);
                        da *= 1.0+0.5*gg;
                        qos.yz = rot(qos.yz,da.y*0.004-0.01);
                        qos.xz = rot(qos.xz,da.x*0.004*ss-gg*ss*(0.03-step(0.0,ss)*0.014)+0.02);

                        float3 eos = qos-float3(0.31,-0.055 - 0.03*animData.x,0.45);
                  
                        // iris
                        float r = length(eos.xy)+0.005;
                        float a = atan2(eos.y,ss*eos.x);
                        float3 iris = float3(0.09,0.0315,0.0135);
                        iris += iris*3.0*(1.0-smoothstep(0.0,1.0, abs((a+3.14159)-2.5) ));
                        //iris *= 0.35+0.7*texture(iChannel2,float2(r,a/6.2831)).x;
                        iris *= 0.35;
                        // base color
                        col = float3(0.42,0.42,0.42);
                        col *= 0.1+0.9*smoothstep(0.10,0.114,r);
                        col = lerp( col, iris, 1.0-smoothstep(0.095,0.10,r) );
                        col *= smoothstep(0.05,0.07,r);
                  
                        // fake occlusion backed in
                        float edis = length((float2(abs(uvw.x),uvw.y)-float2(0.31,-0.07))/float2(1.3,1.0));
                        col *= lerp( float3(1,1,1), float3(0.4,0.2,0.1), linearstep(0.07,0.16,edis) );

                        // fake highlight
                        qos = float3(abs(uvw.x),uvw.yz);
                        col += (0.5-gg*0.3)*(1.0-smoothstep(0.0,0.02,length(qos.xy-float2(0.29-0.05*ss,0.0))));
                  
                        se = 128.0;

                        // fake occlusion
                        focc = 0.2+0.8*pow(1.0-smoothstep(-0.4,1.0,uvw.y),2.0);
                        focc *= 1.0-linearstep(0.10,0.17,edis);
                        //frsha = 0.0;
                    }
                    else if( tm.y<3.5 )// hoodie
                    {
                        sss = 0.0;
                        //col = float3(0.81*texture(iChannel0,uvw*6.0).x);
                        col = 0;
                        ks *= 2.0;
                  
                        // logo
                        if( abs(uvw.x)<0.66 )
                        {
                            float par = length(uvw.yz-float2(-1.05,0.65));
                            col *= lerp(float3(1,1,1),float3(0.6,0.2,0.8)*0.7,1.0-smoothstep(0.1,0.11,par));
                            col *= smoothstep(0.005,0.010,abs(par-0.105));
                        }                

                        // fake occlusion
                        focc = lerp(1.0,
                        0.03+0.97*smoothstep(-0.15,1.7,uvw.z),
                        smoothstep(-1.6,-1.3,uvw.y)*(1.0-clamp(dot(nor.xz,normalize(uvw.xz)),0.0,1.0))
                        );
                  
                        //frsha = lerp(1.0,
                        //            clamp(dot(nor.xz,normalize(uvw.xz)),0.0,1.0),
                        //            smoothstep(-1.6,-1.3,uvw.y)
                        //           );
                        //frsha *= smoothstep(0.85,1.0,length(uvw-float3(0.0,-1.0,0.0)));
                    }
                    else if( tm.y<4.5 )// hair
                    {
                        sss = 0.0;
                        col = (sin(cma.x)>0.7) ? float3(0.03,0.01,0.05)*1.5 :
                        float3(0.04,0.02,0.01)*0.4;
                        ks *= 0.75 + cma.z*18.0;
                        //float te = texture( iChannel2,float2( 0.25*atan(uvw.x,uvw.y),8.0*uvw.z) ).x;
                        float te = 0;
                        col *= 2.0*te;
                        ks *= 1.5*te;
                  
                        // fake occlusion
                        focc  = 1.0-smoothstep(-0.40, 0.8, uvw.y);
                        focc *= 1.0-0.95*smoothstep(-1.20,-0.2,-uvw.z);
                        focc *= 0.5+cma.z*12.0;
                        //frsha = 1.0-smoothstep(-1.3,-0.8,uvw.y);
                        //frsha *= 1.0-smoothstep(-1.20,-0.2,-uvw.z);
                    }
                    else if( tm.y<5.5 )// teeth
                    {
                        sss = 1.0;
                        col = float3(0.3,0.3,0.3);
                        ks *= 1.5;
                        //frsha = 0.0;
                    }

                    float fre = clamp(1.0+dot(nor,rd),0.0,1.0);
                    float occ = focc*calcOcclusion( pos, nor, time );

                    // --------------------------
                    // lighting. just four lights
                    // --------------------------
                    float3 lin = float3(0,0,0);

                    // fake sss
                    float nma = 0.0;
                    if( tm.y<1.5 )
                    {
                        nma = 1.0-smoothstep(0.0,0.12,length((uvw.xy-float2(0.0,-0.37))/float2(2.4,0.7)));
                    }

                    //float3 lig = normalize(float3(0.5,0.4,0.6));
                    float3 lig = float3(0.57,0.46,0.68);
                    float3 hal = normalize(lig-rd);
                    float dif = clamp( dot(nor,lig), 0.0, 1.0 );
                    //float sha = 0.0; if( dif>0.001 ) sha=calcSoftshadow( pos+nor*0.002, lig, 0.0001, 2.0, time, 5.0 );
                    float sha = calcSoftshadow( pos+nor*0.002, lig, 0.0001, 2.0, time, 5.0 );
                    float spe = 2.0*ks*pow(clamp(dot(nor,hal),0.0,1.0),se)*dif*sha*(0.04+0.96*pow(clamp(1.0-dot(hal,-rd),0.0,1.0),5.0));

                    // fake sss for key light
                    float3 cocc = lerp(float3(occ,occ,occ),
                    float3(0.1+0.9*occ,0.9*occ+0.1*occ*occ,0.8*occ+0.2*occ*occ),
                    tinterShadow);
                    cocc = lerp( cocc, float3(1,0.3,0.0), nma);
                    sha = lerp(sha,max(sha,0.3),nma);

                    float3  amb = cocc*(0.55 + 0.45*nor.y);
                    float bou = clamp(0.3-0.7*nor.x, 0.0, 1.0 );

                    lin +=      float3(0.65,1.05,2.0)*amb*1.15;
                    lin += 1.50*float3(1.60,1.40,1.2)*sdif(dot(nor,lig),0.5+0.3*nma+0.2*(1.0-occ)*tinterShadow) * lerp(float3(sha,sha,sha),float3(sha,0.2*sha+0.7*sha*sha,0.2*sha+0.7*sha*sha),tinterShadow);
                    lin +=      float3(1.00,0.30,0.1)*sss*fre*0.6*(0.5+0.5*dif*sha*amb)*(0.1+0.9*focc);
                    lin += 0.35*float3(4.00,2.00,1.0)*bou*occ*col;

                    col = lin*col + spe + fre*fre*fre*0.1*occ;

                    // overall
                    col *= 1.1;
                }
                //if( tm.x==-1.0) col=float3(1,0,0);            
                return float4(col,out_alpha*0.1);
            }

            half4 frag(v2f input) : SV_Target  
            {
                //return half4(1,1,1,0.2);
                half4 fragColor = half4 (1 , 1 , 1 , 1);
                float2 fragCoord = ((input.screenPos.xy) / (input.screenPos.w + FLT_MIN));
                fragCoord *= _ScreenParams.xy;
                float4 tot = 0;
                #if AA > 1                    
                    for (int m = ZEROExtended; m < AA; m++)
                        for (int n = ZEROExtended; n < AA; n++)
                        {
                            // pixel coordinates 
                            float2 o = float2 (float(m) , float(n)) / float(AA) - 0.5;
                            float2 p = (-_ScreenParams.xy + 2.0 * (fragCoord + o)) / _ScreenParams.y;
                            // time coordinate ( motion blurred , shutter = 0.5 ) 
                            float d = 0.5 * sin(fragCoord.x * 147.0) * sin(fragCoord.y * 131.0);
                            float time = _Time.y - 0.5 * (1.0 / 24.0) * (float(m * AA + n) + d) / float(AA * AA - 1);
                #else 
                            float2 p = (-_ScreenParams.xy + 2.0 * fragCoord) / _ScreenParams.y;
                            //return half4((p.yyy),1);
                            float time = _Time.y;
                #endif 
                            time += 2.0;
                            float3 ro; float fl;
                            float3x3 ca = calcCamera( time, ro, fl );
                            float3 rd = normalize(float3(p,fl));
                            rd = mul(rd,ca);
                            float4 col = 0;
                            float tmin = 0;
                            col = renderJap(p,ro,rd,tmin,col,time);
               
                            col = pow(abs(col) , float4 (0.4545, 0.4545, 0.4545, 1.0));
                            tot += col;
                #if AA > 1 
                        }
                    tot /= float(AA * AA);
                #endif

                return col;

                /*

                // compress
                tot = 3.8*tot/(3.0+dot(tot,float3(0.333,0.333,0.333)));

                // vignetting 
                float2 q = fragCoord / _ScreenParams.xy;
                tot *= 0.5 + 0.5 * pow(abs(16.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y)) , 0.15);

                // grade
                tot = tot*float3(1.02,1.00,0.99)+float3(0.0,0.0,0.045);

                // output 
                fragColor = float4 (tot , 1.0);
                return fragColor - 0.1;

                */
            }
        ENDCG
        }
    }
}
