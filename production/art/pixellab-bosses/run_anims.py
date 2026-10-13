"""v2: reference composited on flat magenta (transparent ref made the model invent backgrounds)."""
import sys; sys.path.insert(0,'.')
import gen
from PIL import Image
D={'b1_yeoksin':'floating plague god, long black hair over pale mask face with amber eyes, tattered dark green robe fading into smoke, clawed hands',
 'b2_dueoksini':'giant blue-grey dokkaebi goblin chief, one horn, black gamtu hat, big wooden club, hemp loincloth',
 'b3_yeonhwa':'nine-tailed fox woman in crimson hanbok, white hair, fox ears, nine white tails, blue fox-fire',
 'b4_noeryong':'dark teal thunder serpent dragon, horned head, golden whiskers, blue lightning',
 'b5_yeoksinwang':'tall plague king shaman in black ragged robes with talismans, bone antler crown, green skin, wooden club'}
A={'b1_yeoksin':('hair and robe hem swaying, floating up and down','sweeping both clawed arms forward in a wide slash'),
 'b2_dueoksini':('breathing heavily, shoulders rising and falling','raising the club overhead then smashing it down'),
 'b3_yeonhwa':('gentle sway, tails waving','thrusting arm forward throwing blue fire, tails flaring wide'),
 'b4_noeryong':('body coils undulating, head swaying','lunging forward with open jaws, lightning flashing'),
 'b5_yeoksinwang':('slow breathing, robe fluttering','swinging the club down then raising the other arm')}
NEG='scenery, circle, glow, aura, different character, wings, text'
only=sys.argv[1:] 
for k in D:
    if only and k not in only: continue
    b=Image.open(f'raw/{k}_base.png').convert('RGBA'); bg=Image.new('RGBA',b.size,(255,0,255,255)); bg.alpha_composite(b)
    d=D[k]+', dark muted pixel art, plain flat magenta background'
    gen.anim(k+'_idle',bg,A[k][0],3,None,NEG,4,d)
    gen.anim(k+'_attack',bg,A[k][1],3,3,NEG,4,d)
    gen.anim(k+'_kneel',bg,'slowly kneeling down on one knee with head bowed, defeated and surrendering',5,3,NEG,4,d)
    print('done',k,flush=True)
