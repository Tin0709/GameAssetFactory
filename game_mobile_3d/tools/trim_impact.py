from pathlib import Path
import wave, numpy as np, json, hashlib
root=Path('game_mobile_3d'); source=root/'.godot/impact_recording.wav'
with wave.open(str(source),'rb') as w:
 rate=w.getframerate(); channels=w.getnchannels(); assert w.getsampwidth()==2
 data=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,channels).astype(np.float32)
window=int(rate*.010); mono=np.max(np.abs(data),axis=1)
energy=np.array([np.sqrt(np.mean(mono[i:i+window]**2)) for i in range(0,len(mono),window)])
onset=int(np.flatnonzero(energy>max(energy.max()*.18,250))[0])*window
start=max(0,onset-int(rate*.025)); count=int(rate*.26)
clip=data[start:start+count].copy(); fade=int(rate*.012)
clip[:fade]*=np.linspace(0,1,fade)[:,None];clip[-fade:]*=np.linspace(1,0,fade)[:,None]
clip*=min(1,23000/max(1,np.max(np.abs(clip))))
with wave.open(str(root/'assets/audio/bullet_impact.wav'),'wb') as w:
 w.setnchannels(channels);w.setsampwidth(2);w.setframerate(rate);w.writeframes(clip.astype('<i2').tobytes())
manifest={'bullet_impact':{'source':'audio/game/Bullet impact.mp3','recorded_start_s':start/rate,'length_s':len(clip)/rate,'fade_ms':12,'method':'Godot MP3 decoder + first transient selection, PCM crop; no long multi-impact playback'},'copied_mp3':['pistol_shot','zombie_hit','zombie_death','player_hurt','exp_pickup','zombie_attack','player_death']}
(root/'assets/audio/audio_manifest.json').write_text(json.dumps(manifest,indent=2))
print(json.dumps(manifest))

