"""Editable east-wing extension. Called by build_survival_assets.py with its Y-up helpers."""
import bpy, math, random

def build(g):
    box,rod,ring,sphere,text,empty,parent=[g[k] for k in ['box','rod','ring','sphere','text','empty','parent_keep']]
    plaster,floor,paint,dark,wood,steel,brass,cloth,paper=[g[k] for k in ['plaster','floor','paint','dark','wood','steel','brass','cloth','paper']]
    material=g['material'];collisions=g['collisions']
    # Replace the former exterior boundaries with real doorways to the new wing.
    for obj in list(bpy.context.scene.objects):
        if obj.name.startswith(('Right wall','303 right')):bpy.data.objects.remove(obj,do_unlink=True)
    collisions[:]=[c for c in collisions if c['pos'] not in [[7.08,1.6,-1],[7.16,1.6,4.96]]]
    box('302 east dividing wall',(7.08,1.6,-2.0),(.16,3.2,6.16),plaster,0,True)
    box('East passage header',(7.08,2.87,2.08),(.16,.66,2.0),plaster,0,True)
    for za,zb in [(3.08,4.8),(6.3,6.8)]:box('303 service wall',(7.16,1.6,(za+zb)/2),(.16,3.2,zb-za),plaster,0,True)
    box('303 service lintel',(7.16,2.9,5.55),(.16,.6,1.5),plaster,0,True)
    box('East wing floor',(12.12,-.1,.86),(10.24,.2,11.88),floor,.008,True)
    box('East wing ceiling',(12.12,3.24,.86),(10.24,.18,11.88),plaster,0,True)
    box('East exterior wall',(17.16,1.6,.86),(.16,3.2,11.88),plaster,0,True)
    box('Service rear wall',(12.12,1.6,6.8),(10.24,3.2,.16),plaster,0,True)
    # North-facing residential windows with actual exterior depth.
    box('North sill wall',(12.12,.49,-5.08),(10.24,.98,.16),plaster,0,True)
    box('North window header',(12.12,2.96,-5.08),(10.24,.48,.16),plaster,0,True)
    for xa,xb in [(7.0,8.45),(10.95,13.40),(15.90,17.24)]:box('North window pier',((xa+xb)/2,1.85,-5.08),(xb-xa,1.74,.16),plaster,0,True)
    glass=bpy.data.materials['window_glass'];diffuser=bpy.data.materials['light_diffuser']
    for x in [9.7,14.65]:
        box('East window glass',(x,1.85,-5.12),(2.50,1.72,.025),glass,.001,True)
        for xx in [x-1.25,x,x+1.25]:box('East window mullion',(xx,1.85,-4.99),(.055,1.84,.12),steel,.006)
        for y in [.98,1.86,2.72]:box('East window bar',(x,y,-4.99),(2.55,.055,.12),steel,.004)
        box('East deep window sill',(x,.97,-4.93),(2.7,.085,.34),paper,.009)
        for i in range(22):
            xx=x+random.uniform(-1.20,1.20);y=random.uniform(1.03,2.68)
            rod('Rain streak east',(xx,y,-4.975),(xx,y-random.uniform(.02,.09),-4.975),.003,glass,8)
    city=material('east_courtyard_concrete',(.16,.20,.21),.98)
    box('Distant east building',(12.2,3,-10.8),(13,8,.5),city,0)
    for x in [7.8,10.1,12.4,14.7,17.0]:
        for y in [1.0,3.5,6.0]:box('Distant east window',(x,y,-10.53),(1.05,1.45,.018),dark,.006)
    # Parallel corridor partitions. Four generous 1.56 m openings.
    for z in [1.08,3.08]:
        for xa,xb in [(7.08,8.92),(10.48,14.72),(16.28,17.16)]:box('East hall partition',((xa+xb)/2,1.6,z),(xb-xa,3.2,.16),plaster,0,True)
        for x in [9.70,15.50]:
            box('East room lintel',(x,2.88,z),(1.56,.64,.16),plaster,0,True)
            for xx in [x-.79,x+.79]:box('East room jamb',(xx,1.23,z),(.08,2.46,.22),wood,.008)
    # Two apartments connected by a rough service opening, plus a laundry/store divider.
    for za,zb in [(-5.0,-2.85),(-1.15,1.08)]:box('Unit dividing wall',(12.08,1.6,(za+zb)/2),(.16,3.2,zb-za),plaster,0,True)
    box('Broken partition header',(12.08,2.91,-2.0),(.16,.58,1.7),plaster,0,True)
    rubble=material('exposed_masonry',(.27,.22,.17),.98)
    for z in [-2.88,-1.12]:
        for i in range(9):
            block=box('Ragged masonry',(12.07,.14+i*.29,z),(.21,.19,.11),rubble,.02)
            block.rotation_euler.z=random.uniform(-.2,.2)
    for i in range(9):box('Masonry dust',(12.08+random.uniform(-.4,.4),.025,-2.0+random.uniform(-.4,.4)),(.06,.04,.1),rubble,.01)
    box('Laundry store divider',(12.08,1.6,4.94),(.16,3.2,3.72),plaster,0,True)
    # Articulated 304 and property-store doors use the same runtime interactions as 302.
    for name,x,z in [('Dynamic_Unit304',8.94,1.08),('Dynamic_Utility',14.74,3.08)]:
        door=empty(name,(x,0,z))
        parent(box('East door leaf',(x+.75,1.2,z),(1.50,2.4,.065),paint,.01),door)
        for y in [.55,1.68]:parent(box('East door inset',(x+.75,y,z+.04),(1.23,.83,.02),dark,.012),door)
        parent(rod('East door handle',(x+1.29,1.03,z+.075),(x+1.44,1.03,z+.075),.015,brass),door)
    for x in [8.05,11.6,14.05,16.6]:
        box('East strip lamp mount',(x,3.10,2.08),(1.10,.08,.22),steel,.006)
        box('East strip lamp diffuser',(x,3.045,2.08),(.96,.035,.17),diffuser,.008)
    for z in [1.18,2.98]:
        for xa,xb in [(7.2,8.85),(10.55,14.65),(16.35,17.0)]:
            box('East hall skirting',((xa+xb)/2,.11,z),(xb-xa,.12,.035),dark,.005)
            box('East hall handrail',((xa+xb)/2,1.30,z),(xb-xa,.055,.035),paint,.004)
    # Residential room: abandoned table, sofa, pantry, luggage and household detail.
    upholstery=material('east_sofa_fabric',(.16,.20,.19),.99)
    box('304 sofa base',(7.78,.35,-3.42),(.96,.45,2.10),wood,.05,True)
    box('304 sofa back',(7.39,.94,-3.42),(.24,1.04,2.15),upholstery,.075)
    for z in [-4.15,-3.43,-2.71]:box('304 sofa cushion',(7.85,.63,z),(.85,.17,.68),upholstery,.06)
    for z in [-4.49,-2.35]:box('304 sofa arm',(7.8,.77,z),(.95,.39,.18),upholstery,.04)
    box('304 table',(9.55,.56,-3.2),(1.2,.10,.8),wood,.015,True)
    for x in [9.08,10.02]:
        for z in [-3.48,-2.92]:box('304 table leg',(x,.28,z),(.065,.56,.065),wood,.006)
    for i in range(4):box('304 papers',(9.35+i*.08,.619+i*.003,-3.19),(.22,.005,.28),paper,.001)
    box('304 counter',(11.0,.46,-4.56),(1.68,.87,.68),paint,.012,True)
    box('304 countertop',(11.0,.92,-4.56),(1.78,.07,.75),paper,.012,True)
    for x in [10.55,11.4]:
        box('304 counter door',(x,.47,-4.195),(.77,.75,.028),paint,.008)
        rod('304 handle',(x-.12,.75,-4.17),(x+.12,.75,-4.17),.012,brass)
    # Small supplies share simple recognizable boxes, never individual auto-pickups.
    def crate(name,pos,size,mat):
        x,y,z=pos;w,h,d=size
        box(name,pos,size,mat,.014)
        box(name+' tape',(x,y+h/2+.004,z),(.09,.01,d+.015),paper,.001)
        for xx in [x-w*.35,x+w*.35]:box(name+' latch',(xx,y,z-d/2-.012),(.035,.07,.026),brass,.004)
    crate('304 pantry box',(11.05,1.10,-4.5),(.58,.30,.50),paper)
    crate('304 suitcase',(7.92,.29,-.45),(.66,.50,.47),dark)
    rod('Luggage grip',(7.73,.56,-.45),(8.1,.56,-.45),.018,steel)
    # Makeshift medical room: cots, privacy curtain, task board and supply trolley.
    enamel=material('aid_enamel',(.52,.57,.54),.52)
    aid_cloth=material('aid_bedding',(.32,.42,.41),.97)
    for x in [13.25,15.55]:
        box('Aid cot frame',(x,.39,-3.65),(1.01,.12,2.12),steel,.012,True)
        box('Aid cot mattress',(x,.57,-3.65),(.95,.24,2.04),enamel,.06)
        box('Aid folded blanket',(x,.73,-3.25),(.98,.10,1.04),aid_cloth,.025)
        box('Aid pillow',(x,.75,-4.35),(.70,.15,.35),cloth,.05)
        for xx in [x-.41,x+.41]:
            rod('Aid cot leg',(xx,.06,-4.45),(xx,.44,-4.45),.029,steel)
            rod('Aid cot leg',(xx,.06,-2.85),(xx,.44,-2.85),.029,steel)
            rod('Aid headrail',(xx,.4,-4.72),(xx,1.03,-4.72),.019,steel)
        rod('Aid headrail bar',(x-.41,1.03,-4.72),(x+.41,1.03,-4.72),.019,steel)
    rod('Privacy pole',(14.45,.05,-4.3),(14.45,2.35,-4.3),.022,steel)
    rod('Privacy rail',(14.45,2.35,-4.6),(14.45,2.35,-2.65),.018,steel)
    for i in range(14):box('Curtain folds',(14.45+math.sin(i*1.7)*.055,1.50,-4.5+i*.125),(.025,1.60,.15),aid_cloth,.008)
    box('Supply trolley shelf',(16.45,.85,-1.55),(.86,.075,.68),steel,.008,True)
    for x in [16.10,16.80]:
        for z in [-1.82,-1.28]:rod('Trolley leg',(x,.05,z),(x,.93,z),.02,steel)
    crate('Aid supply chest',(16.45,1.06,-1.55),(.63,.35,.52),enamel)
    box('Supply mark vertical',(16.45,1.06,-1.816),(.035,.16,.009),paint,.001)
    box('Supply mark horizontal',(16.45,1.06,-1.82),(.16,.035,.009),paint,.001)
    # Laundry: front-loading machines, water lines, laundry basket, folding bench.
    for x in [8.20,9.42,10.64]:
        box('Laundry machine',(x,.57,6.28),(.91,1.14,.82),enamel,.04,True)
        box('Laundry control strip',(x,.99,5.859),(.78,.16,.026),dark,.005)
        ring('Laundry door',(x,.52,5.84),.28,.034,steel,'z')
        sphere('Laundry drum',(x,.52,5.85),(.239,.239,.025),dark)
        ring('Laundry inner seal',(x,.52,5.817),.23,.014,dark,'z')
        for xx in [x+.13,x+.28]:sphere('Washer dial',(xx,1.01,5.824),(.038,.038,.020),paper)
    for y in [1.50,2.33]:rod('Laundry water main',(7.40,y,6.65),(11.86,y,6.65),.027,steel)
    rod('Laundry riser',(11.75,.12,6.65),(11.75,2.7,6.65),.037,steel)
    ring('Laundry valve',(11.75,1.84,6.54),.13,.014,brass,'z')
    box('Folding bench',(10.65,.63,4.10),(1.55,.12,.61),wood,.014,True)
    for x in [10.05,11.25]:box('Bench leg',(x,.29,4.1),(.09,.58,.48),wood,.01)
    crate('Laundry basket',(10.64,.88,4.10),(.60,.37,.43),cloth)
    for i in range(3):box('Discarded linen',(11.15,.72+i*.043,4.12),(.40,.08,.36),aid_cloth,.02)
    # Property store: workbench, wall tools, shelves and wrapped reserves.
    box('Property workbench',(16.54,.86,4.88),(.83,.12,1.88),wood,.015,True)
    for z in [4.15,5.61]:box('Workbench support',(16.54,.42,z),(.72,.84,.10),steel,.01)
    crate('Property toolbox',(16.49,1.12,4.85),(.58,.40,.64),paint)
    crate('Property reserves',(14.10,.39,6.08),(.91,.72,.63),paper)
    for y in [.28,1.0,1.72]:box('Property shelving',(13.0,y,6.36),(1.43,.06,.63),steel,.008,True)
    for x in [12.4,13.6]:box('Property shelf post',(x,1.0,6.38),(.05,2.0,.60),steel,.004)
    for x,z in [(12.75,6.30),(13.27,6.31)]:crate('Property storage carton',(x,1.22,z),(.42,.38,.40),paper)
    for z in [4.32,4.72,5.12]:rod('Hanging pipe tool',(17.01,1.50,z),(17.01,2.18,z+.11),.020,steel)
    # Scuffs and physical wayfinding stay restrained and use the established palette.
    for x,z in [(8.3,1.18),(11.7,2.98),(14.1,1.18),(16.6,2.98)]:
        box('East wall plate',(x,1.85,z),(.65,.26,.025),dark,.007)
    for x in [8.2,11.8,14.2,16.6]:
        box('Ceiling conduit',(x,2.88,2.83),(2.15,.035,.04),steel,.004)
    print('EAST_WING_BUILT',len(collisions),'collision boxes')
