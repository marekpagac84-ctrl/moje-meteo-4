RADAR TRACKING ENGINE - VYVOJOVA VERZIA
=======================================

Pridane:
- lib/services/radar_tracking_service.dart
- napojenie do lib/services/sky_context_service.dart
- zobrazenie skutocnej radarovej vzdialenosti/pohybu v existujucom detaile dazda

Ako to funguje:
- nacita posledne 4 radarove snimky
- v okoli pouzivatela vyhlada suvislu zrazkovu oblast
- porovna polohu oblasti medzi snimkami
- vypocita smer a rychlost pozorovaneho pohybu
- vypocita vzdialenost najblizsej hrany zrazok
- extrapoluje najblizsie priblizenie k GPS polohe
- ETA zobrazi iba vtedy, ked pozorovana draha skutocne pretina koridor pouzivatela
- pri neistote ETA radsej nezobrazi

Dolezite:
Aktualny vyvojovy provider je RainViewer public API. Je vhodny na osobny/vyvojovy
prototyp, nie ako automaticky predpoklad pre komercnu verziu. Pred publikovanim
platenej/komercnej aplikacie treba dohodnut komercne podmienky alebo provider
vymenit. Tracking matematika je oddelena od zvysku aplikacie, aby sa provider dal
neskor vymenit bez prerabania UI.

UI:
Hlavny dizajn aplikacie sa nemenil. Nove udaje su iba v existujucom detaile
najblizsich zrazok.
