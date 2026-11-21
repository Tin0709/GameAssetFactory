"""Make local 64x64 source color guides, preserving source scale in world units."""
from pathlib import Path
import argparse
from PIL import Image
import numpy as np
from scipy.ndimage import distance_transform_edt

def build(input_dir,output):
    # Matching width across four views leaves a common map for X/Z and Y/Z.
    height=52
    output.mkdir(parents=True,exist_ok=True)
    for name in ("front","back","right","left"):
        image=Image.open(input_dir/f"{name}.png").convert("RGBA")
        arr=np.array(image.getchannel("A"))
        y,x=np.where(arr>127)
        feet=x[y>y.max()-.10*(y.max()-y.min())]
        cx=(feet.min()+feet.max())/2
        scale=height/image.height
        resized=image.resize((round(image.width*scale),height),Image.Resampling.BOX)
        canvas=Image.new("RGBA",(64,64))
        canvas.paste(resized,(round(32-cx*scale),6))
        pixels=np.array(canvas)
        foreground=pixels[:,:,3]>115
        nearest=distance_transform_edt(~foreground,return_distances=False,return_indices=True)
        colors=pixels[nearest[0],nearest[1],:3]
        Image.fromarray(colors).save(output/f"{name}.png")

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs",type=Path)
    parser.add_argument("output",type=Path)
    args=parser.parse_args()
    build(args.inputs,args.output)

