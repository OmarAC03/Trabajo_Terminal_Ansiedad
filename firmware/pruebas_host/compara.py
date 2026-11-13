import subprocess, numpy as np, sys
sys.path.insert(0,'.')
from prueba_host import genera, evalua_app
print('caso                  | firmware | seg. válidos | RMSSD vs real | FC vs real | SpO2 (esperada)')
for ac,hr,R in ((300,70,0.5),(800,75,0.5),(1500,90,0.5),(3000,65,0.7)):
    beats=genera('s.csv',ac=ac,hr=hr,R=R); rr=np.diff(beats*1000); real=np.sqrt(np.mean(np.diff(rr)**2))
    esp=-45.060*R*R+30.354*R+94.845
    for nom,exe in (('v1','./sim_v1'),('v2','./sim')):
        out=subprocess.run([exe,'s.csv','10.0'],capture_output=True,text=True).stdout.splitlines()
        lin=[l for l in out if l.startswith('{')]
        try: v,t,rm,fc,sp=evalua_app(lin)
        except Exception: v,t,rm,fc,sp=0,len(lin),float('nan'),float('nan'),float('nan')
        print(f'AC {ac:4d} FC {hr} R {R}    | {nom}       | {v:3d}/{t:3d}      | {rm:5.1f} vs {real:4.1f} | {fc:5.1f} vs {60000/rr.mean():4.1f} | {sp:5.1f} ({esp:.1f})')
