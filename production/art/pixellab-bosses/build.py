import json, numpy as np
from PIL import Image, ImageDraw
from collections import deque
S='../../../src/assets/sprites/'
def key(im):
    a=np.array(im.convert('RGBA')).astype(int); h,w=a.shape[:2]
    corner=np.median(np.concatenate([a[:3,:3].reshape(-1,4),a[:3,-3:].reshape(-1,4),a[-3:,:3].reshape(-1,4),a[-3:,-3:].reshape(-1,4)]),0)[:3]
    ismag=(np.abs(a[...,:3]-corner).sum(-1)<110)&(a[...,0]>110)&(a[...,2]>130)&(a[...,1]<110)
    bg=np.zeros((h,w),bool); q=deque()
    for x in range(w):
        for y in (0,h-1):
            if ismag[y,x]: bg[y,x]=True; q.append((y,x))
    for y in range(h):
        for x in (0,w-1):
            if ismag[y,x] and not bg[y,x]: bg[y,x]=True; q.append((y,x))
    while q:
        y,x=q.popleft()
        for dy,dx in((1,0),(-1,0),(0,1),(0,-1)):
            ny,nx=y+dy,x+dx
            if 0<=ny<h and 0<=nx<w and ismag[ny,nx] and not bg[ny,nx]: bg[ny,nx]=True; q.append((ny,nx))
    a[bg,3]=0; return Image.fromarray(a.astype('uint8'),'RGBA')
BOSSES=[('b1_yeoksin','1장 역신','yeoksin',['idle','attack','kneel']),('b2_dueoksini','2장 두억시니','dueoksini',['idle','attack','kneel']),
 ('b3_yeonhwa','3장 구미호 연화','yeonhwa',[]),('b4_noeryong','4장 이무기 뇌룡','noeryong',[]),('b5_yeoksinwang','5장 역신왕','yeoksinwang',[])]
FPS={'idle':6,'attack':10,'kneel':6}
gens={'b1_yeoksin':(1,3),'b2_dueoksini':(1,3),'b3_yeonhwa':(1,0),'b4_noeryong':(1,0),'b5_yeoksinwang':(1,0)}
frames={}
for k,label,slug,acts in BOSSES:
    base=Image.open(f'raw/{k}_base.png').convert('RGBA')
    rows=[('base',[base])]+[(a,[key(Image.open(f'raw/{k}_{a}_{i}.png')) for i in range(4)]) for a in acts]
    sh=Image.new('RGBA',(256,64*len(rows)),(0,0,0,0)); meta={'boss':label,'cell':[64,64],'sheet':f'{slug}_sheet.png','rows':[]}
    for r,(n,fs) in enumerate(rows):
        for i,f in enumerate(fs): sh.alpha_composite(f,(i*64,r*64))
        meta['rows'].append({'row':r,'name':n,'frames':len(fs),'fps':FPS.get(n,0),'facing':'east(side)' })
    meta['notes']='west = horizontal flip. hit = idle frame + white flash (not generated). '+('' if acts else 'BASE ONLY: animations not generated (Pixellab 402 quota exhausted).')
    meta['generations']={'base':1,'animate':gens[k][1]}
    sh.save(f'{slug}_sheet.png'); json.dump(meta,open(f'{slug}_sheet.json','w'),ensure_ascii=False,indent=1); frames[k]=rows
# overview
OLD={'b1_yeoksin':('plague_god.png',8),'b2_dueoksini':('yokai/dokkaebi_extra.png',8),'b3_yeonhwa':('yokai/gumiho.png',8),'b4_noeryong':('yokai/imugi.png',8),'b5_yeoksinwang':('yokai/plague_king.png',8)}
Z=3; W=1100; RH=64*Z+30
ov=Image.new('RGBA',(W,5*RH+10),(52,52,62,255)); d=ImageDraw.Draw(ov); y=4
for k,label,slug,acts in BOSSES:
    d.text((6,y),f'ch{k[1]} {slug}: base | idle0 | attack2 | kneel3 (new 64x64 cell, 3x)   ->   existing game sprite frame0 (2x)',fill=(255,255,255,255))
    pick=[('base',0),('idle',0),('attack',2),('kneel',3)]; rows=dict(frames[k])
    for j,(n,i) in enumerate(pick):
        if n in rows:
            ov.alpha_composite(rows[n][i].resize((192,192),0),(4+j*196,y+16))
        else: d.text((4+j*196+40,y+100),'(not generated: 402)',fill=(255,160,160,255))
    of,nf=OLD[k]; o=Image.open(S+of).convert('RGBA'); cw=o.width//nf; f0=o.crop((0,0,cw,o.height)).resize((cw*2,o.height*2),0)
    ov.alpha_composite(f0,(W-f0.width-10,y+16)); d.text((W-f0.width-10,y+16+f0.height+2),f'old {cw}x{o.height}px',fill=(255,255,255,255))
    y+=RH
ov.crop((0,0,W,y)).save('overview.png')
