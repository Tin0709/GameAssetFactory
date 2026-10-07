"""Reuse the established dense seam, collision and preservation tests for new V3."""
from pathlib import Path
BASE=Path(__file__).resolve().parent
code=(BASE/'validate_turning_r3.py').read_text()
code=code.replace("turning_study_r3_review","turning_study_r5_review").replace("R3_Turn_Authoring","R5_Turn_Authoring").replace("R2_R3_Author_","R2_R5_Author_").replace("_Reference_V2'","_Reference_V3'").replace("<.00402","<.00803").replace('R3_VALIDATED','R5_VALIDATED')
exec(compile(code,str(BASE/'validate_turning_r5.py'),'exec'))
