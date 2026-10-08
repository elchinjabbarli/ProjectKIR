# AudioGenerator (opsiyonel)

Spec 87 alternatifi: build-time WAV üretimi. Bu MVP, runtime AVAudioEngine
sentezini (ProjectKIR/Audio/ProceduralSFX.swift) kullanır — dosya gerekmez.

Build-time aracı istenirse aynı formüller Python'a taşınabilir:
- Rezonans: pitch sweep 70→110 Hz + exp decay (spec 88-89)
- Metal: 5 çarpık partial (spec 91)
- Makine: 46 Hz yumuşatılmış saw + 1.2 sn thump periyodu (spec 92)
