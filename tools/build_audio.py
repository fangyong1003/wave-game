"""Original procedural sound design: no downloaded or third-party samples."""
from pathlib import Path
import math, random, wave, array
OUT=Path(__file__).resolve().parents[1]/'game/assets/audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
def write(name,duration,fn,loop=False):
    random.seed(name);samples=[];last=0
    for i in range(int(duration*RATE)):
        t=i/RATE;n=random.uniform(-1,1);last=last*.86+n*.14
        v=fn(t,n,last)
        if not loop:v*=min(t/.008,1)*min((duration-t)/.04,1)
        samples.append(v)
    if loop:
        fade=2205
        for i in range(fade):
            w=i/fade;samples[i]=samples[i]*w+samples[-fade+i]*(1-w)
        samples=samples[:-fade]
    pcm=array.array('h',(int(max(-1,min(1,v))*32760) for v in samples))
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
write('rain',12,lambda t,n,l:l*.30+n*.016,True)
write('room_tone',12,lambda t,n,l:(math.sin(t*math.tau*60)*.016+math.sin(t*math.tau*119.8)*.006+l*.025),True)
write('water',8,lambda t,n,l:(n-l)*.07*(.7+.3*math.sin(t*47))+math.sin(t*1300)*.006,True)
write('drain',8,lambda t,n,l:l*.30*(.8+.2*math.sin(t*8)),True)
write('step',.22,lambda t,n,l:(l*.6+math.sin(t*math.tau*95)*.06)*math.exp(-t*22))
write('ratchet',.40,lambda t,n,l:(n*.10+math.sin(t*math.tau*790)*.08)*math.exp(-((t%0.065)*75)))
write('click',.25,lambda t,n,l:(math.sin(t*math.tau*670)*.2+n*.05)*math.exp(-t*23))
write('cup',.7,lambda t,n,l:(math.sin(t*math.tau*1900)*.06+math.sin(t*math.tau*2700)*.04)*math.exp(-t*11))
write('printer',1.5,lambda t,n,l:(math.sin(t*math.tau*(130+20*math.sin(t*17)))*.06+n*.04)*(.5+.5*math.sin(t*60)))
print('AUDIO_BUILD_OK')
# Original survival combat and feedback layers.
write('swing',.36,lambda t,n,l:(n-l)*.22*math.sin(min(1,t/.36)*math.pi)**2)
write('hit_flesh',.38,lambda t,n,l:(math.sin(t*math.tau*(100-100*t))*.40+l*.55+n*.07)*math.exp(-t*15))
write('hit_wood',.48,lambda t,n,l:(math.sin(t*math.tau*155)*.24+n*.14+l*.36)*math.exp(-t*12))
write('hit_metal',.8,lambda t,n,l:(math.sin(t*math.tau*731)*.15+math.sin(t*math.tau*1169)*.11+n*.10*math.exp(-t*25))*math.exp(-t*6))
write('hit_stone',.32,lambda t,n,l:(n*.30+math.sin(t*math.tau*210)*.20)*math.exp(-t*20))
write('hit_glass',1.05,lambda t,n,l:((n-l)*.27+math.sin(t*math.tau*(2800+200*math.sin(t*35)))*.07)*math.exp(-t*5)*(0.5+0.5*math.cos(t*90)**2))
write('snarl',.9,lambda t,n,l:(math.sin(t*math.tau*(78+11*math.sin(t*7)))*.14+math.sin(t*math.tau*157)*.06+l*.35)*math.sin(t/.9*math.pi)**2)
write('hurt',.45,lambda t,n,l:(math.sin(t*math.tau*68)*.30+l*.30)*math.exp(-t*7))
write('pickup',.20,lambda t,n,l:(math.sin(t*math.tau*610)*.10+n*.045)*math.exp(-t*18))
write('eat',.65,lambda t,n,l:l*.2*(.5+.5*math.sin(t*32))*math.sin(t/.65*math.pi)**2)
write('level',1.2,lambda t,n,l:sum(math.sin(t*math.tau*f)*.065*math.exp(-max(0,t-i*.13)*5) if t>i*.13 else 0 for i,f in enumerate([330,440,660])) )
write('door',.60,lambda t,n,l:(l*.35+math.sin(t*math.tau*(180-t*100))*.05)*math.exp(-t*5))
print('SURVIVAL_AUDIO_BUILD_OK')

# Different tool mass and air movement; contact layers mix with the struck surface.
write('wrench_swing',.24,lambda t,n,l:(n-l)*.18*math.sin(min(1,t/.24)*math.pi)**1.5)
write('bat_swing',.50,lambda t,n,l:(l*.90+n*.10)*math.sin(min(1,t/.50)*math.pi)**2)
write('wrench_contact',.34,lambda t,n,l:(math.sin(t*math.tau*1231)*.11+math.sin(t*math.tau*1879)*.07)*math.exp(-t*17))
write('bat_contact',.42,lambda t,n,l:(math.sin(t*math.tau*79)*.35+l*.40)*math.exp(-t*14))
write('search',1.30,lambda t,n,l:(l*.48+n*.035)*(0.3+0.7*math.sin(t*19)**6)*math.sin(min(1,t/1.3)*math.pi))

# Original ranged layers: sharp firearm impulse vs elastic release, mechanical reloads.
write('pistol_fire',.52,lambda t,n,l:(n*.85*math.exp(-t*65)+l*.65*math.exp(-t*16)+math.sin(t*math.tau*95)*.42*math.exp(-t*24)))
write('crossbow_fire',.44,lambda t,n,l:(math.sin(t*math.tau*(310-190*t))*.25+l*.32+n*.09)*math.exp(-t*12))
write('dry_fire',.12,lambda t,n,l:(n*.16+math.sin(t*math.tau*1250)*.13)*math.exp(-t*55))
write('pistol_reload',1.45,lambda t,n,l:sum((n*.17+math.sin(t*math.tau*f)*.07)*math.exp(-(t-start)*45) if t>=start else 0 for start,f in [(0,670),(.58,950),(1.18,1320)]))
write('crossbow_load',1.85,lambda t,n,l:(l*.26+n*.035)*(.4+.6*math.sin(t*38)**4)*math.sin(min(1,t/1.85)*math.pi)+sum(n*.10*math.exp(-(t-start)*40) if t>=start else 0 for start in [.1,1.6]))
print('RANGED_AUDIO_BUILD_OK')

# Original melee-upgrade layers: low body impact and heavier floor/wall landing.
write('heavy_body',.48,lambda t,n,l:(math.sin(t*math.tau*(70-28*t))*.50+l*.48+n*.14*math.exp(-t*35))*math.exp(-t*12))
write('body_land',.65,lambda t,n,l:(math.sin(t*math.tau*56)*.40+l*.58+n*.12)*math.exp(-t*9))
print('MELEE_UPGRADE_AUDIO_BUILD_OK')
