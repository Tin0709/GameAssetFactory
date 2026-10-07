from pathlib import Path
p=Path(__file__).resolve().parent/'encode_straight_r2s.py'
exec(compile(p.read_text().replace('straight_study_r2s_review','turning_study_r3_review').replace('R2S_ENCODE_DONE','R3_ENCODE_DONE'),str(p),'exec'))
