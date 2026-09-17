MOJE METEO – FINAL VISUAL STORM ORB 4x4

Tento projekt vznikol z pôvodného funkčného main ZIPu.
Zachované: pôvodné Living Weather UI, scény, AI SKY, senzory, mapy a existujúce funkcie.
Pridané: RadarTrackingService, WeatherIntelligenceService radar integrácia, StormOrbWidget v appke,
Android 4x4 home-screen widget, WorkManager refresh a vizuálny cinematic Storm Orb renderer.

Dôležité:
- Existuje iba jeden MainActivity.kt.
- package/namespace/applicationId ostáva com.example.moje_meteo.
- Home widget používa reálny radarový PNG z RainViewer a vykreslí ho do 2.5D orb vizuálu.
- Ak radar nemá spoľahlivé ETA, widget nevymýšľa presný čas.
- Automatický refresh je cez WorkManager (~15 min podľa Android plánovania), tlačidlo ↻ vyžiada okamžitý refresh.
