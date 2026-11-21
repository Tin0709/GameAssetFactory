"""Paint light and dark cloth clusters for an editable 64-square hood texture."""
from pathlib import Path
from PIL import Image,ImageDraw

OUT=Path(__file__).resolve().parent/"private"/"square-refine"/"hood-cloth-64.png"
palette=dict(d="#393225",s="#423b2a",m="#4c462e",l="#584e33",a="#6c5d3a",h="#816d44",g="#9e7946")
side=[
"mlmlamhlaalslmdd", "mllmaaamlsllmldd", "llmmaallmlsmlmmd", "aallmmlmllsmldms",
"laslmmllaalmmmds", "lmdlmslmmlaammds", "ammdlmmllalmllms", "almdlmllmslmlmms",
"amlmlmmlmslmmmsd", "lammddmmmlmllmms", "llmlsdmmmlmlllsd", "almmmlsmmmdmlgms",
"mlmllmlsmldmmals", "mlldmllsmlmmmgls", "lmmsmmlsmlmmalls", "mssmmllmsmmlslsd",
]
rear=[
"alallamlaalmamlm", "mllmllmllmllmmll", "mssmmllmmllmdmll", "mssmllasmmmlsmlm",
"mmsmllmmlmllmmlm", "lmmmlsmlmllsmmml", "lmlllsmllllsllmm", "lmllmmsmlsmmmllm",
"mmlsmmmmmmdmmlms", "llmlmmsmmlmmmlls", "lmlmmmsllmmmlmls", "mllmmlsllmsmlmsm",
"ammlmlmmlmsmmlms", "lsmmmmlmsllsmmms", "lmlslmmlmmlmsmsm", "mlllmmmsmamlmsmm",
]
front=[
"lhaalmmalalmmall","lhaaallaaammlaam","mmllmmslmlmmmlmm","mmllmmslmmdmmlsm",
"lllmmmmmdmmmmllm","aamhmmmldmmsmmma","mmlammmldmmlsmmh","lsllmmslmmmlsmml",
"lmllsmlmmlllmsll","mlmlsmmmlmmmsmmd","lmsllmmlmmmsmmsd","mllsmmsmllmsmmad",
"mllmlmsmmdmmsmld","smlmlmmmlsmmmdls","mmsllmmldlmsmdds","smlsmlssmldmmsmd"]
top=[
"haaallaaamllmdll","aahhammalalmmdls","aalaammlalmlmmlm","lalaaallmlalmlmm",
"lmlallmmalalmmsm","lalmlmlmllmllmml","llmllmlmllmlamml","mlammalmmsallmmm",
"mmmmlmmmsmalmlmm","lmmlmmmsmmldlmms","lmmlmmmslmsmmlms","amllmsmmllmmslmm",
"lmlmmmlmllmmslmm","mmlmmlsllmmlmsmm","mllmsmmllmmlmlmm","mlammlsmlmsmmsmm"]
img=Image.new("RGB",(64,64))
draw=ImageDraw.Draw(img)
# Pillow's top two tiles correspond to upper UV islands.
for row,col,pattern in ((0,0,side),(0,1,top),(1,0,front),(1,1,rear)):
    assert all(len(line)==16 for line in pattern)
    for y,line in enumerate(pattern):
        for x,c in enumerate(line):
            draw.rectangle((col*32+x*2,row*32+y*2,col*32+x*2+1,row*32+y*2+1),fill=palette[c])
img.save(OUT)


