"""31 distinct, purpose-built room recipes; shared craft vocabulary, different plans."""
import math
import modeling as m
from modeling import *

NAMES = {
 'A':('苹果果园屋','APPLE ORCHARD'), 'B':('船屋码头','BOAT HOUSE'),
 'C':('蛋糕烘焙坊','CAKE BAKERY'), 'D':('鼓屋音乐厅','DRUM HOUSE'),
 'E':('蛋壳孵化屋','EGG NURSERY'), 'F':('巨花温室','FLOWER HOUSE'),
 'G':('地球仪旅行馆','GLOBE TRAVELS'), 'H':('帽子裁缝店','HAT ATELIER'),
 'I':('冰淇淋驿亭','ICE CREAM'), 'J':('玻璃罐收藏馆','JAR COLLECTION'),
 'K':('风筝工坊','KITE WORKSHOP'), 'L':('灯笼驿站','LANTERN LODGE'),
 'M':('蘑菇邻居屋','MUSHROOM COTTAGE'), 'N':('鸟巢观察屋','NEST LOOKOUT'),
 'O':('猫头鹰图书馆','OWL LIBRARY'), 'P':('南瓜农场屋','PUMPKIN FARM'),
 'Q':('拼布故事馆','QUILT STORIES'), 'R':('机器人工坊','ROBOT WORKSHOP'),
 'S':('星形天文台','STAR OBSERVATORY'), 'T':('火车车站','TRAIN STATION'),
 'U':('雨伞气象屋','UMBRELLA WEATHER'), 'V':('休眠火山观察站','VOLCANO FIELD STATION'),
 'W':('鲸鱼海洋馆','WHALE BAY'), 'X':('木琴海边舞台','XYLOPHONE STAGE'),
 'Y':('毛线手作屋','YARN STUDIO'), 'Z':('斑马邮局','ZEBRA POST'),
 'school':('学校门厅与校园','WELCOME TO SCHOOL'),
 'classroom':('教室','OUR CLASSROOM'), 'canteen':('食堂','SCHOOL KITCHEN'),
 'playground':('操场','PLAY TOGETHER'), 'home':('玩家小屋','HOME SWEET HOME')
}
LABELS = {
 'A':['门前篮子','左侧果树','中央分拣台','右侧洗果池','出口礼物架'],
 'B':['岸边路牌','左侧长凳','中央系船柱','右侧货架','船舱门'],
 'C':['门口订单板','左侧材料架','中央料理台','右侧烤箱','出口取餐窗'],
 'D':['门口节目牌','左侧乐器架','中央鼓台','右侧排练席','出口纪念墙'],
 'E':['门口照料板','左侧软垫','中央孵化台','右侧食水架','出口观察窗'],
 'F':['门口种子盒','左侧花盆台','中央花床','右侧水池','出口花束架'],
 'G':['旅行公告板','地图书架','地球仪台','行李台','明信片架'],
 'H':['试戴镜','帽子展示架','裁剪台','缝纫机','取衣架'],
 'I':['口味菜单','蛋筒架','冰淇淋柜台','配料台','取餐台'],
 'J':['收藏登记台','玻璃罐架','分类台','放大观察台','收藏展示柜'],
 'K':['材料篮','风筝骨架','制作台','彩带架','试飞风向台'],
 'L':['迎客牌','灯笼架','茶桌','留言台','礼物灯架'],
 'M':['欢迎地毯','邻居沙发','餐桌','厨房','相册柜'],
 'N':['观察记录板','树枝长凳','鸟巢观察台','望远镜','观察相册架'],
 'O':['借阅台','左侧书架','阅读桌','故事角','还书车'],
 'P':['农场公告板','种子架','南瓜分拣台','灌溉台','收获货架'],
 'Q':['故事封面架','布片架','拼布台','故事坐垫','作品展示架'],
 'R':['维修订单板','零件架','机器人工作台','工具台','交付台'],
 'S':['星空导览板','星图架','观测望远镜','记录台','星象展示台'],
 'T':['时刻表','候车长凳','检票台','行李架','站台门'],
 'U':['天气公告板','雨具架','气象观测台','记录台','出行提示架'],
 'V':['地质路线牌','岩石标本架','火山模型台','观察工具台','发现展示架'],
 'W':['海洋导览牌','贝壳架','潮池观察台','水生观察窗','旅行相册架'],
 'X':['节目牌','琴槌架','木琴台','排练长凳','演出纪念墙'],
 'Y':['编织图样板','毛线架','编织台','礼物包装台','作品架'],
 'Z':['寄信指南','信件格架','打包台','称重台','收件箱'],
 'school':['校园公告栏','书包柜','欢迎台','阅读长椅','作品墙'],
 'classroom':['课程板','图书角','学习桌','创作台','作品墙'],
 'canteen':['今日菜单','餐具台','餐桌','取餐窗','回收台'],
 'playground':['活动牌','器材架','球场','游戏角','休息长凳'],
 'home':['信箱小桌','衣柜','生活桌','床边角','纪念架']
}

# Five permanent approach points. Furniture stands behind/beside each point.
POINTS=[(-3.5,-3.4),(-4.8,-.7),(0,-.3),(4.7,-.7),(4.6,-3.9)]
PROP=[(-4.3,-4.8),(-5.1,1.1),(0,1.7),(5.0,1.25),(5.2,-5.15)]

def loci(key, points=None):
    labels=LABELS[key];points=points or POINTS
    for i,(p,label) in enumerate(zip(points,labels),1):
        anchor(f'SG_MEMORY_{i:02}',p,label,f'Locus_{i:02}')
    anchor('SG_SPAWN',(0,-5.65),'进入点')
    anchor('SG_EXIT',(0,-6.45),'返回学校' if key in ('classroom','canteen','playground') else '返回主地图')
    anchor('SG_NPC_HOST',(-2.2,-1.4),'主人交谈点')

def locus(i):group(f'1{i}_Locus_{i:02}')

def start(key,wall='cream',floor_mat='lightwood',style='room',width=16,depth=14):
    room_shell(width,depth,wall,floor_mat,style)
    if style=='room':title_banner(NAMES[key][1])
    else:
        # A rear pavilion title is part of the structure, never a quiz station.
        for x in [-4.2,4.2]:box('Pavilion_Post',(x,6.3,1.9),(.20,.22,3.8),'wood')
        title_banner(NAMES[key][1],y=6.3)

def finish(key,points=None):
    group('70_Set_Dressing')
    if key not in ('B','N','T','V','W','X','playground'):
        plant('Entry_Flowers',-6.9,-5.8,flower=True,s=.7)
        plant('Back_Greenery',6.7,5.7,s=1.1)
    loci(key,points)

def A():
    start('A',floor_mat='grass',style='garden')
    rug('Orchard_Path',(0,-1.6),(3.5,9.8),'sand')
    rug('Harvest_Crosspath',(0,1),(12.8,2.3),'sand')
    for x,y,s in [(-6,4.4,1),(-2.9,5.0,.9),(3.5,5.1,1.1),(6.2,4.7,.9)]:tree('Orchard_Tree',x,y,True,s)
    locus(1);basket('Locus_01_Basket',-4.3,-4.8);parcel('Folded_Check_Cloth',-5,-4.8,.2,.6,'rose')
    locus(2);tree('Locus_02_Apple_Tree',-5.1,1.1,True,1.0)
    basket('Picking_Basket',-6.5,1.0)
    locus(3);z=table('Locus_03_Sorting_Table',0,1.7,3.0,1.3)
    for x in [-.8,0,.8]:basket('Sorting_Crate',x,1.7,z,True)
    locus(4);sink('Locus_04_Wash',5,1.25)
    locus(5);shelf('Locus_05_Gifts',5.2,-5.45,2.2,2,'parcels',1.5)
    group('70_Set_Dressing');bench('Orchard_Bench',-4.6,5.1,2.2);board('Harvest_Sign',-4.9,-6,'PICK & SHARE','Fresh apples',z=1.35,w=2.2)
    finish('A')

def C():
    start('C',wall='pink',floor_mat='cream')
    grid_tiles('Bakery_Floor',0,0,15.5,13.5,'cream','ivory',1)
    window('Bakery_Window_Left',-5.2,6.75,2.3,2.4,1.5)
    window('Bakery_Window_Right',5.1,6.75,2.3,2.4,1.5)
    for x in [-6,-4,-2,0,2,4,6]:ball('Cream_Cornice',(x,6.65,3.7),(1.0,.3,.25),'ivory')
    locus(1);board('Locus_01_Orders',-4.3,-4.8,'TODAY','Mix - bake - share',color='teal')
    locus(2);shelf('Locus_02_Ingredients',-5.1,1.1,3,3,'jars',2.7)
    locus(3);z=table('Locus_03_Island',0,1.7,3.6,1.6,1.08,'ivory',True)
    cyl('Mixing_Bowl',(0,1.6,z+.2),.39,.32,'teal',24,top=.5)
    beam('Wooden_Spoon',(-.1,1.6,z+.3),(.4,1.8,z+.9),.045,'oak')
    cyl('Flour_Bowl',(-1.1,1.7,z+.16),.3,.25,'cream');cake('Cake_In_Progress',1.1,1.65,z,.65)
    locus(4);box('Locus_04_Oven',(5,1.25,.95),(2.4,1.5,1.9),'clay',.18)
    box('Oven_Door_Frame',(5,.44,.95),(1.85,.13,1.2),'oak',.2)
    box('Oven_Glass',(5,.35,.95),(1.55,.04,.88),'navy',.14)
    for x in [4.4,5,5.6]:ball('Oven_Knob',(x,.36,1.65),(.1,.07,.1),'gold')
    box('Oven_Hood',(5,1.3,2.3),(2.8,1.7,.6),'cream',.16)
    collider('Oven',(5,1.25,1.2),(2.5,1.6,2.4))
    locus(5);z=table('Locus_05_Pickup',5.2,-5.15,2.7,1.0,1.05,'teal',True)
    cake('Pickup_Cake',5.2,-5.15,z,.8)
    group('70_Set_Dressing');z=table('Back_Pastry_Counter',0,5.7,6,1,1.05,'oak',True)
    for x in [-1.9,-.6,.7,2]:cake('Pastry_Display',x,5.7,z,.6)
    finish('C')

def school():
    start('school',wall='cream',floor_mat='sand')
    grid_tiles('Hall_Pavers',0,0,15.5,13.5,'sand','cream',1)
    # Three clearly separated, reachable portals on the back wall.
    for x,target,title in [(-5,'CLASSROOM','CLASSROOM'),(0,'CANTEEN','CANTEEN'),(5,'PLAYGROUND','PLAYGROUND')]:
        door('School_'+title,x,6.73,title)
        anchor('SG_DOOR_'+target,(x,5.3),title)
        rug('Door_Welcome_Mat',(x,5.1),(2.4,1.2),'teal')
    locus(1);board('Locus_01_Notice',-4.3,-4.8,'OUR SCHOOL','Friends grow together')
    locus(2);shelf('Locus_02_Cubbies',-5.1,1.1,3,2,'parcels',1.7)
    for x in [-5.9,-5.1,-4.3]:box('School_Bag',(x,1.0,.8),(.5,.3,.55),['rose','blue','yellow'][round((x+5.9)/.8)%3],.1)
    locus(3);z=table('Locus_03_Welcome',0,1.7,3.2,1.2,1.0,'teal',True)
    plant('Welcome_Flowers',.8,1.7,z,True,.55);box('Visitor_Book',(-.6,1.7,z+.06),(.85,.55,.1),'paper')
    locus(4);bench('Locus_04_Reading_Bench',5,1.25,3,'oak');pillow('Reading_Cushion',5,1.2,.79,'rose')
    locus(5);board('Locus_05_Art',5.2,-5.15,'OUR GALLERY','Made by us',color='rose')
    finish('school')

def classroom():
    start('classroom',wall='mint')
    box('Class_Blackboard',(0,6.67,2.15),(6.2,.15,1.85),'teal')
    text('Morning_Greeting','Good morning!',(0,6.55,2.35),.48)
    text('Class_Activity','Read  -  Make  -  Share',(0,6.54,1.8),.28)
    clock_face('Classroom_Clock',5.5,6.65,2.75)
    locus(1);board('Locus_01_Class_Plan',-4.3,-4.8,'TODAY','Read a story')
    locus(2);shelf('Locus_02_Book_Corner',-5.1,1.1,3,3,'books',2.25)
    locus(3);z=table('Locus_03_Shared_Desk',0,1.7,3.1,1.4,.86,'lightwood')
    for x in [-.85,.85]:box('Open_Notebook',(x,1.65,z+.035),(.65,.44,.06),'paper');stool('Class_Stool',x,2.8,.55)
    for x in [-3.2,0,3.2]:
        z=table('Rear_Pupil_Desk',x,4.25,2,1,.86)
        box('Pupil_Book',(x,4.2,z+.04),(.65,.45,.08),'rose');stool('Pupil_Chair',x,3.45,.55)
    locus(4);z=table('Locus_04_Art',5,1.25,2.4,1.3,.86)
    for x in [4.4,5,5.6]:jar('Paint_Pot',x,1.4,z,.17,['rose','blue','yellow'][round((x-4.4)/.6)%3])
    locus(5);board('Locus_05_Art_Display',5.2,-5.15,'OUR STORIES','Everyone has a voice',color='blue')
    finish('classroom')

def canteen():
    start('canteen',wall='cream',floor_mat='cream')
    grid_tiles('Kitchen_Tiles',0,0,15.5,13.5,'ivory','mint',1)
    for x in [-4.6,0,4.6]:
        box('Serving_Window_Frame',(x,6.7,2.15),(3.6,.2,1.6),'oak')
        box('Serving_Window_Dark',(x,6.55,2.15),(3.3,.05,1.3),'teal')
    locus(1);board('Locus_01_Menu',-4.3,-4.8,'LUNCH TODAY','Soup - bread - fruit')
    locus(2);z=table('Locus_02_Cutlery',-5.1,1.1,2.4,1.2,1,'lightwood',True)
    for x in [-5.7,-5.1,-4.5]:
        for j in range(4):cyl('Clean_Plates',(x,1.1,z+j*.05),.28,.035,'ivory')
    locus(3);z=table('Locus_03_Dining',0,1.7,3.4,1.4,.85)
    bench('Dining_Rear_Bench',0,2.85,3,'teal',False)
    for x in [-1,0,1]:cyl('Lunch_Plate',(x,1.7,z+.035),.30,.04,'white');apple('Lunch_Apple',x,1.7,z+.21,.16)
    locus(4);z=table('Locus_04_Serving',5,1.25,2.7,1.4,1.1,'teal',True)
    for x in [4.3,5,5.7]:cyl('Soup_Pot',(x,1.25,z+.23),.3,.4,'metal');cyl('Pot_Lid',(x,1.25,z+.45),.33,.04,'metal')
    locus(5);z=table('Locus_05_Return',5.2,-5.15,2.4,1,1,'oak',True)
    box('Return_Tray',(5.2,-5.15,z+.06),(1.8,.65,.12),'teal')
    group('70_Set_Dressing');table('Kitchen_Back_Counter',0,5.6,13,1.1,1.05,'cream',True)
    plant('Kitchen_Herbs',-5,5.6,1.15,False,.5)
    finish('canteen')

def playground():
    start('playground',floor_mat='grass',style='court')
    box('SG_FLOOR_Court',(0,1.5,.015),(8,7.4,.03),'teal',.1)
    for x in [-3.8,3.8]:box('Court_Sideline',(x,1.5,.04),(.045,7,.02),'ivory',0)
    for y in [-2,1.5,5]:box('Court_Crossline',(0,y,.04),(7.6,.045,.02),'ivory',0)
    ring('Court_Center',(0,1.5,.05),1.05,.025,'ivory')
    # Raised hoops on rear edge, fully outside the approach route.
    beam('Hoop_Post',(0,5.7,0),(0,5.7,3.4),.09,'teal')
    box('Hoop_Backboard',(0,5.6,3.1),(1.7,.12,1.1),'ivory')
    ring('Basketball_Hoop',(0,5.1,2.85),.42,.035,'orange')
    collider('Hoop_Post',(0,5.7,1.8),(.4,.4,3.6))
    locus(1);board('Locus_01_Games',-4.3,-4.8,'LET US PLAY','Take turns - have fun')
    locus(2);shelf('Locus_02_Equipment',-5.8,1.4,2.3,2,'none',1.7)
    for j,color in enumerate(['orange','blue','yellow']):ball('Play_Ball',(-6.5+j*.65,1.4,1.1),(.28,)*3,color)
    locus(3);cyl('Locus_03_Court_Marker',(0,1.5,.03),.45,.025,'yellow')
    locus(4);box('Locus_04_Slide_Platform',(5.6,2.5,1.0),(1.6,1.6,2),'oak')
    slide=box('Slide_Chute',(5.6,1.0,1.0),(1.3,3.2,.15),'yellow',.12);slide.rotation_euler[0]=.5
    collider('Slide',(5.6,1.9,1.0),(1.8,3.4,2.0))
    for x in [4.9,6.3]:beam('Slide_Rail',(x,-.3,.42),(x,2.4,2.2),.07,'teal')
    for i in range(5):box('Slide_Step',(5.6,3.4+i*.16,.3+i*.35),(1.1,.35,.15),'teal')
    locus(5);bench('Locus_05_Rest',5.2,-5.15,2.8)
    group('70_Set_Dressing');tree('Play_Shade_Tree',-6.5,5.3,False,1)
    # Hopscotch is a side activity, not the route to enter or leave.
    for j in range(5):box('Hopscotch',(-5.8,-2+j*.65,.025),(.65,.58,.035),['rose','yellow','blue'][j%3]);text('Hopscotch_Number',str(j+1),(-5.8,-2+j*.65,.05),.27,'ivory','up')
    finish('playground',[(-3.5,-3.4),(-4.4,-.4),(0,-.3),(4.1,-.7),(4.6,-3.9)])

def home():
    start('home',wall='cream')
    window('Home_Window_Left',-5.3,6.74,2.35,2.6,1.5)
    window('Home_Window_Right',5.2,6.74,2.35,2.6,1.5)
    rug('Living_Rug',(0,1.3),(5.4,4.8),'rose')
    locus(1);z=table('Locus_01_Mail_Table',-4.3,-4.8,1.9,1, .78)
    parcel('Letter',-4.3,-4.8,z+.04,.6,'paper');plant('Mail_Table_Plant',-4.9,-4.8,z,False,.45)
    locus(2);box('Locus_02_Wardrobe',(-5.1,1.1,1.45),(2.8,1.3,2.9),'teal',.14)
    for x in [-5.8,-4.4]:box('Wardrobe_Panel',(x,.4,1.5),(1.25,.10,2.5),'mint');ball('Wardrobe_Knob',(x+.25,.31,1.4),(.07,)*3,'gold')
    collider('Wardrobe',(-5.1,1.1,1.45),(2.9,1.4,2.9));anchor('SG_WARDROBE',(-4.8,-.7),'换装衣柜')
    locus(3);z=table('Locus_03_Living_Table',0,1.7,2.4,1.4,.7)
    jar('Tea_Cup',-.55,1.7,z,.17,'ivory');box('Home_Open_Book',(.45,1.65,z+.05),(.7,.5,.08),'paper')
    box('Sofa_Base',(0,4.1,.48),(3.4,1.2,.70),'teal',.2)
    box('Sofa_Back',(0,4.6,1.0),(3.4,.32,.8),'teal',.15)
    for x in [-1.5,1.5]:box('Sofa_Arm',(x,4.0,.86),(.38,1.25,.75),'teal',.15)
    for x in [-.85,.85]:pillow('Sofa_Cushion',x,4.12,.98,'yellow',(.65,.55,.25))
    collider('Sofa',(0,4.1,.65),(3.5,1.4,1.3))
    locus(4);box('Locus_04_Bed_Frame',(5,2.25,.36),(2.5,3.6,.55),'oak')
    box('Bed_Mattress',(5,2.25,.75),(2.35,3.45,.48),'ivory',.22)
    box('Bed_Quilt',(5,1.7,1.03),(2.36,2.35,.15),'rose',.14)
    for x in [4.45,5.55]:pillow('Bed_Pillow',x,3.35,1.09,'paper',(.85,.60,.20))
    box('Bed_Headboard',(5,4.05,1.06),(2.7,.20,1.6),'oak')
    collider('Bed',(5,2.25,.6),(2.7,3.9,1.2));anchor('SG_BED',(4.7,-.7),'休息床边')
    locus(5);shelf('Locus_05_Keepsakes',5.2,-5.4,2.3,2,'parcels',1.6)
    group('70_Set_Dressing');shelf('Home_Pantry',-5.4,5.6,2.8,2,'jars',1.9)
    # Optional decorations are parented to stable empty nodes for whole-model visibility.
    for ident,p in [('FLOWER_BOX',(-6.4,-2.2)),('PICNIC',(1.0,-3.25)),('LAMP',(2.5,5.4))]:
        anchor('SG_DECOR_'+ident,p,ident)
        root=empty('SG_DECOR_MODEL_'+ident,(0,0,0));root['optional_decoration']=True
        m.PARENT=root
        if ident=='FLOWER_BOX':
            box('Decor_Flower_Box',(*p,.25),(1.9,.70,.5),'oak');plant('Decor_Flowers',p[0]-.45,p[1],.45,True,.50);plant('Decor_Flowers',p[0]+.45,p[1],.45,True,.50)
        elif ident=='PICNIC':
            rug('Decor_Picnic_Mat',p,(2.1,1.5),'mint');basket('Decor_Picnic_Basket',p[0]+.6,p[1]+.25,0,True)
        else:
            cyl('Decor_Lamp_Base',(*p,.10),.38,.2,'gold');beam('Decor_Lamp_Stem',(*p,.15),(*p,2.1),.055,'gold');cyl('Decor_Lamp_Shade',(*p,2.1),.65,.75,'yellow',32,top=.36)
        m.PARENT=None
    finish('home')

def B():
    start('B',floor_mat='oak',style='water')
    # Water is a contained rear basin, the complete front boardwalk remains traversable.
    box('Harbour_Water',(0,4.7,.015),(12,3.7,.03),'water')
    collider('Harbour_Basin',(0,4.9,.55),(12,3.7,1.1))
    for x in [-6,6]:
        for y in [3.3,5.9]:cyl('Mooring_Post',(x,y,.7),.16,1.4,'wood')
    # Plump open hull with ribs and benches, not a flat boat symbol.
    verts=[(-2.8,0,.45),(-1.8,-.85,.45),(1.8,-.85,.45),(3,0,.45),(1.8,.85,.45),(-1.8,.85,.45),(-2.5,0,1.2),(-1.8,-1,1.2),(1.8,-1,1.2),(2.8,0,1.2),(1.8,1,1.2),(-1.8,1,1.2)]
    ob=mesh('Boat_Wooden_Hull',verts,[(0,1,2,3,4,5)]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)],'wood');ob.location=(0,4.7,0);soften(ob,.09)
    for x in [-1.4,0,1.4]:box('Boat_Bench',(x,4.7,1.0),(.5,1.6,.13),'lightwood')
    beam('Boat_Mast',(0,4.7,.8),(0,4.7,3.3),.07,'wood')
    mesh('Boat_Sail',[(.1,4.7,3.1),(.1,4.7,1.5),(1.7,4.7,1.5)],[(0,1,2)],'cream')
    locus(1);board('Locus_01_Directions',-4.3,-4.8,'BOAT HOUSE','Pack - carry - travel')
    locus(2);bench('Locus_02_Bench',-5.1,1.1,2.7)
    locus(3);cyl('Locus_03_Mooring_Bollard',(0,1.7,.52),.32,1.04,'wood');ring('Mooring_Rope',(0,1.7,.8),.37,.07,'sand');collider('Bollard',(0,1.7,.55),(.8,.8,1.1))
    locus(4);shelf('Locus_04_Cargo',5,1.25,2.8,2,'parcels',1.9)
    locus(5);door('Locus_05_Cabin',5.2,-5.45,'CABIN','teal');collider('Cabin_Back',(5.2,-5.45,1.5),(2.4,.4,3))
    finish('B')

def D():
    start('D',wall='rose',floor_mat='oak')
    arc_wall('Acoustic_Curve',0,2.5,4.6,0,math.pi,2.6,'clay')
    cyl('Drum_Stage',(0,3.6,.08),3.4,.16,'darkwood',64)
    # The stage is visual floor-height dressing; no central impassable raised platform.
    locus(1);board('Locus_01_Programme',-4.3,-4.8,'MUSIC TODAY','Listen - play - share')
    locus(2);shelf('Locus_02_Instrument_Shelf',-5.1,1.1,2.6,2,'none',2.0)
    for x in [-5.8,-5.1,-4.4]:drum('Small_Drum',x,1.1,.25,.27,.45,'yellow')
    locus(3);drum('Locus_03_Big_Drum',0,1.7,0,.9,1.1);collider('Big_Drum',(0,1.7,.65),(2,2,1.3))
    for x in [-1.7,1.7]:drum('Companion_Drum',x,3.5,0,.55,.75,'teal')
    locus(4);bench('Locus_04_Rehearsal',5,1.25,2.7,'rose')
    locus(5);board('Locus_05_Memories',5.2,-5.15,'OUR FIRST SHOW','Together sounds better',color='purple')
    for x in [-3,0,3]:lantern('Music_Lantern',x,5.9,3.5,'yellow',.3)
    finish('D')

def E():
    start('E',wall='ivory')
    arc_wall('Eggshell_Curved_Nursery',0,3.3,3.9,0,math.pi,2.2,'ivory')
    for j in range(9):
        a=math.pi*j/8;ob=box('Eggshell_Crown',(3.9*math.cos(a),3.3+3.9*math.sin(a),2.35),(.65,.32,.65),'ivory');ob.rotation_euler[1]=.5
    locus(1);board('Locus_01_Care',-4.3,-4.8,'LITTLE FRIENDS','Warm - gentle - quiet',color='mint')
    locus(2);rug('Locus_02_Soft_Nest',(-5.1,1.1),(2.6,2),'rose')
    for x,y in [(-5.7,1),(-4.8,1.6),(-4.5,.6)]:pillow('Nursery_Cushion',x,y,.16,'yellow',(1,.8,.28))
    locus(3);z=table('Locus_03_Incubator',0,1.7,2.8,1.5,.85,'lightwood',True)
    for x in [-.8,0,.8]:ring('Egg_Nest',(x,1.7,z+.12),.34,.12,'sand');ball('Nursery_Egg',(x,1.7,z+.42),(.25,.25,.38),'ivory')
    locus(4);z=table('Locus_04_Feed_Water',5,1.25,2.7,1.2,.8,'mint',True)
    for x in [4.4,5.5]:cyl('Feed_Bowl',(x,1.25,z+.12),.35,.20,'yellow');cyl('Water_Bowl',(5.5,1.25,z+.23),.29,.025,'water')
    locus(5);board('Locus_05_Observation',5.2,-5.15,'WATCH THEM GROW','Small - soft - sleepy',color='blue')
    ball('Chick_Body',(5.2,-5.37,1.6),(.28,.15,.3),'yellow');ball('Chick_Eye',(5.3,-5.52,1.73),(.035,)*3,'black')
    finish('E')

def F():
    start('F',wall='mint',floor_mat='sand',style='garden')
    # Back half of a greenhouse: open front and no roof occlusion.
    for x in [-7,-3.5,0,3.5,7]:
        beam('Greenhouse_Upright',(x,6.4,0),(x,6.4,4.4),.07,'teal')
        beam('Greenhouse_Rafter',(x,6.4,4.4),(x,3.9,5.5),.065,'teal')
    for z in [1.6,3.2,4.4]:beam('Greenhouse_Crossbar',(-7,6.4,z),(7,6.4,z),.06,'teal')
    for x in [-5,0,5]:garden_box('Rear_Flower_Bed',x,5.2,3,1.25)
    locus(1);z=table('Locus_01_Seeds',-4.3,-4.8,2,1,.8);basket('Seed_Basket',-4.3,-4.8,z,False)
    locus(2);z=table('Locus_02_Potting',-5.1,1.1,2.6,1.2,1)
    for x in [-5.8,-5.1,-4.4]:plant('Potting_Flowers',x,1.1,z,True,.65)
    locus(3);garden_box('Locus_03_Flower_Bed',0,1.7,3.2,1.7)
    locus(4);sink('Locus_04_Garden_Sink',5,1.25)
    locus(5);z=table('Locus_05_Bouquets',5.2,-5.15,2.4,1,1)
    for x in [4.6,5.3,5.9]:plant('Bouquet',x,-5.15,z,True,.65)
    finish('F')

def G():
    start('G',wall='blue')
    locus(1);board('Locus_01_Travel',-4.3,-4.8,'WHERE NEXT?','Explore our world')
    locus(2);shelf('Locus_02_Atlases',-5.1,1.1,2.8,3,'books')
    locus(3);cyl('Locus_03_Globe_Base',(0,1.7,.15),1.0,.3,'wood');beam('Globe_Stand',(0,1.7,.3),(0,1.7,1.4),.12,'gold')
    ball('Globe_Ocean',(0,1.7,2),(.95,)*3,'blue',32,20)
    for dx,dy,dz,s in [(-.4,-.65,.5,.38),(.4,-.8,-.1,.35),(.6,.3,.6,.28),(-.3,-.5,-.6,.3)]:ball('Globe_Continent',(dx,1.7+dy,2+dz),(s,s*.45,s*1.2),'sage')
    ring('Globe_Meridian',(0,1.7,2),1.13,.045,'gold',(math.pi/2,.3,0));collider('Globe',(0,1.7,1.1),(2.3,2.3,2.2))
    locus(4);z=table('Locus_04_Luggage',5,1.25,2.7,1.3,.8);parcel('Travel_Case',5,1.25,z+.5,1.1,'clay')
    locus(5);shelf('Locus_05_Postcards',5.2,-5.3,2.3,2,'books',1.6)
    for x in [-4.3,0,4.3]:window('Travel_Map_Frame',x,6.7,2.1,2.3,1.4)
    finish('G')

def H():
    start('H',wall='lavender')
    rug('Fitting_Runway',(0,0),(3,10),'purple')
    locus(1);box('Locus_01_Mirror_Frame',(-4.3,-4.8,1.4),(1.45,.20,2.7),'gold',.15);box('Mirror',(-4.3,-4.94,1.4),(1.2,.05,2.4),'glass',.1);collider('Mirror',(-4.3,-4.8,1.4),(1.5,.3,2.8))
    locus(2);shelf('Locus_02_Hat_Shelf',-5.1,1.1,3,2,'none',2.4)
    for z in [.3,1.4]:
        for x in [-5.9,-4.4]:hat('Hat_Display',x,1.1,z,.6,'rose' if z<1 else 'teal')
    locus(3);z=table('Locus_03_Cutting',0,1.7,3.4,1.6);box('Cloth_In_Progress',(0,1.7,z+.03),(2.4,1.1,.06),'rose');beam('Tailor_Ruler',(-1,1.4,z+.09),(.9,1.7,z+.09),.03,'lightwood')
    locus(4);z=table('Locus_04_Sewing',5,1.25,2.5,1.2);box('Sewing_Machine_Base',(5,1.25,z+.1),(1.3,.7,.2),'teal');box('Machine_Arm',(5.3,1.25,z+.6),(.25,.4,1.0),'teal');box('Machine_Bridge',(4.95,1.25,z+.95),(.9,.4,.2),'teal');beam('Needle',(4.6,1.25,z+.3),(4.6,1.25,z+.9),.02,'metal')
    locus(5);z=table('Locus_05_Pickup',5.2,-5.15,2.2,1,1);hat('Ready_Hat',5.2,-5.15,z,.72,'yellow')
    for x in [-5.2,0,5.2]:hat('Wall_Hat',x,6.3,1.7,.65,'rose')
    finish('H')

def I():
    start('I',floor_mat='cream',style='garden')
    for x in [-5.7,5.7]:beam('Icecream_Awning_Post',(x,4.6,0),(x,4.6,3.8),.09,'teal')
    for j in range(12):box('Striped_Awning',(-5.5+j,5.3,3.8),(1,2.6,.16),'pink' if j%2 else 'ivory')
    locus(1);board('Locus_01_Flavours',-4.3,-4.8,'PICK A FLAVOUR','Vanilla - berry - mint',color='rose')
    locus(2);z=table('Locus_02_Cones',-5.1,1.1,2.6,1.2,1.1,'cream',True)
    for x in [-5.8,-5.1,-4.4]:cyl('Cone_Stack',(x,1.1,z+.4),.05,.8,'sand',20,top=.26)
    locus(3);z=table('Locus_03_Gelato_Counter',0,1.7,3.4,1.5,1,'teal',True)
    for j,col in enumerate(['pink','ivory','mint','clay']):
        x=-1.2+j*.8;box('Gelato_Pan',(x,1.7,z+.06),(.7,1.1,.12),'metal');ball('Gelato_Scoop',(x,1.7,z+.22),(.3,.40,.16),col)
    locus(4);shelf('Locus_04_Toppings',5,1.25,2.6,2,'jars',1.9)
    locus(5);z=table('Locus_05_Collect',5.2,-5.15,2.3,1,1,'rose',True)
    for x,col in [(4.7,'pink'),(5.6,'mint')]:cyl('Cone',(x,-5.15,z+.3),.03,.6,'sand',20,top=.23);ball('Ice_Cream',(x,-5.15,z+.72),(.3,)*3,col)
    for x in [-3,3]:stool('Icecream_Cafe_Stool',x,4.9,.65,'rose')
    finish('I')

def J():
    start('J',wall='mint')
    for x in [-5,0,5]:shelf('Rear_Collection',x,5.9,3.3,3,'jars',2.4)
    locus(1);board('Locus_01_Register',-4.3,-4.8,'LITTLE TREASURES','Keep a curious eye')
    locus(2);shelf('Locus_02_Jars',-5.1,1.1,2.7,3,'jars',2.5)
    locus(3);z=table('Locus_03_Sorting',0,1.7,3.1,1.7)
    for x,col in [(-1,'yellow'),(0,'rose'),(1,'mint')]:jar('Sorting_Jar',x,1.7,z,.3,col)
    locus(4);z=table('Locus_04_Inspect',5,1.25,2.4,1.3);ring('Magnifier',(5,1.25,z+.65),.4,.055,'gold',(math.pi/2,.4,0));beam('Magnifier_Handle',(5.3,1.25,z+.4),(5.7,1.25,z),.06,'wood')
    locus(5);z=table('Locus_05_Display',5.2,-5.15,2.3,1,1,'cream',True);jar('Keepsake_Jar',5.2,-5.15,z,.43,'blue')
    finish('J')

def kite(name,x,y,z,s=1,color='rose'):
    vs=[(x,y,z+s),(x+s*.7,y,z),(x,y,z-s),(x-s*.7,y,z),(x,y-.08,z)]
    mesh(name,vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],color)
    beam(name+'_Spar',(x-s*.7,y-.1,z),(x+s*.7,y-.1,z),.025,'oak');beam(name+'_Spar',(x,y-.1,z-s),(x,y-.1,z+s),.025,'oak')
    for j in range(5):ball(name+'_Tail',(x+math.sin(j)*.18,y,z-s-j*.23),(.14,.04,.07),'yellow')

def K():
    start('K',wall='cream')
    for x,col in [(-5,'blue'),(0,'rose'),(5,'yellow')]:kite('Wall_Kite',x,6.65,2.1,1.05,col)
    locus(1);basket('Locus_01_Material_Basket',-4.3,-4.8,0,False)
    for dx in [-.2,0,.2]:beam('Bamboo_Strips',(-4.3+dx,-4.8,.3),(-4.7+dx,-4.8,1.9),.025,'lightwood')
    locus(2);kite('Locus_02_Frame',-5.1,1.1,1.9,1.1,'cream');collider('Kite_Frame',(-5.1,1.1,1.5),(2,.3,3))
    locus(3);z=table('Locus_03_Making',0,1.7,3.4,1.8);box('Kite_Fabric',(0,1.7,z+.04),(1.6,1.3,.05),'teal');beam('Kite_Stick',(-.8,1.05,z+.08),(.8,2.35,z+.08),.03,'oak')
    locus(4);shelf('Locus_04_Ribbons',5,1.25,2.7,2,'yarn',2.0)
    locus(5);beam('Locus_05_Wind_Pole',(5.2,-5.15,0),(5.2,-5.15,2.6),.08,'oak');kite('Wind_Test_Kite',5.2,-5.15,2.4,.55,'rose');collider('Wind_Pole',(5.2,-5.15,1.4),(.35,.35,2.8))
    finish('K')

def L():
    start('L',wall='clay',floor_mat='oak')
    for x in [-6,-3,0,3,6]:lantern('Festival_Lantern',x,5.6,3.4,'rose' if x%2 else 'yellow',.52)
    locus(1);board('Locus_01_Welcome',-4.3,-4.8,'COME ON IN','A warm light awaits',color='clay')
    locus(2);shelf('Locus_02_Lantern_Shelf',-5.1,1.1,3,2,'none',2.5)
    for x in [-5.8,-4.4]:lantern('Shelf_Lantern',x,1.1,.8,'yellow',.32);lantern('Shelf_Lantern',x,1.1,1.85,'rose',.32)
    locus(3);rug('Tea_Rug',(0,1.7),(4,3),'rose');z=table('Locus_03_Tea',0,1.7,2.6,1.4,.65)
    for x in [-.8,0,.8]:jar('Tea_Cup',x,1.7,z,.14,'ivory')
    for x in [-1,1]:pillow('Tea_Cushion',x,3,.17,'yellow',(.9,.8,.3))
    locus(4);z=table('Locus_04_Messages',5,1.25,2.6,1.2);box('Guestbook',(5,1.25,z+.05),(1,.65,.10),'paper')
    locus(5);z=table('Locus_05_Lantern_Gift',5.2,-5.15,2.2,1,1);lantern('Gift_Lantern',5.2,-5.15,z+.5,'teal',.35)
    finish('L')

def M():
    start('M',wall='sand',floor_mat='oak')
    arc_wall('Cottage_Round_Wall',0,3.6,4.2,0,math.pi,2.1,'sand')
    # Mushroom-shaped stove with a stout stem, broad red cap and cream spots.
    cyl('Mushroom_Stove_Stem',(0,5.2,1.0),.8,2,'cream')
    ball('Mushroom_Stove_Cap',(0,5.2,2.2),(1.5,1.1,.55),'red')
    for x,y in [(-.65,4.6),(.6,4.6),(0,5.1)]:ball('Mushroom_Cap_Spot',(x,y,2.62),(.22,.18,.045),'ivory')
    box('Stove_Door',(0,4.35,.9),(.85,.12,.8),'darkwood',.15);collider('Mushroom_Stove',(0,5.2,1.2),(2.1,1.9,2.4))
    locus(1);rug('Locus_01_Welcome_Rug',(-4.3,-4.8),(2.5,1.5),'sage');basket('Welcome_Basket',-5.1,-4.8)
    locus(2);bench('Locus_02_Sofa',-5.1,1.1,2.8,'rose');pillow('Cottage_Cushion',-5.1,1.1,.85,'yellow')
    locus(3);z=table('Locus_03_Dining',0,1.7,2.6,1.6,.8);cake('Tea_Cake',0,1.7,z,.55)
    locus(4);sink('Locus_04_Kitchen',5,1.25)
    locus(5);shelf('Locus_05_Albums',5.2,-5.3,2.3,2,'books',1.6)
    finish('M')

def N():
    start('N',floor_mat='oak',style='garden')
    for x in [-6.5,6.5]:tree('Lookout_Tree',x,5.4,False,1.3)
    arc_wall('Nest_Woven_Rear',0,3.7,3.7,0,math.pi,1.3,'wood')
    for z in [.25,.6,1.0]:ring('Nest_Woven_Ring',(0,3.7,z),3.65,.12,'oak',portion=.5)
    locus(1);board('Locus_01_Field_Notes',-4.3,-4.8,'BIRDS AT HOME','Watch - listen - care')
    locus(2);bench('Locus_02_Branch_Bench',-5.1,1.1,2.6,'wood')
    locus(3);z=table('Locus_03_Nest_Stand',0,1.7,2.5,1.6,.9)
    for r in [.45,.60,.75]:ring('Little_Nest',(0,1.7,z+.13),r,.1,'oak')
    for dx in [-.25,.25]:ball('Bird_Egg',(dx,1.7,z+.3),(.2,.17,.27),'blue')
    locus(4);telescope('Locus_04_Birdwatch',5,1.25,0,.85)
    locus(5);shelf('Locus_05_Albums',5.2,-5.3,2.3,2,'books',1.6)
    finish('N')

def O():
    start('O',wall='sage',floor_mat='oak')
    for x in [-5.5,-2.8,0,2.8,5.5]:shelf('Library_Rear_Books',x,5.9,2.5,4,'books',3.15)
    for x in [-2.0,2.0]:
        ring('Owl_Eye_Frame',(x,6.35,3.7),.52,.10,'gold',(math.pi/2,0,0));ball('Owl_Eye',(x,6.3,3.7),(.16,.07,.16),'navy')
    locus(1);z=table('Locus_01_Borrow',-4.3,-4.8,2.6,1,1.0,'teal',True);box('Borrow_Book',(-4.3,-4.8,z+.05),(.8,.6,.1),'paper')
    locus(2);shelf('Locus_02_Wing_Books',-5.1,1.1,2.8,3,'books',2.5)
    locus(3);z=table('Locus_03_Read',0,1.7,3.2,1.6,.85)
    for x in [-.9,.9]:box('Reading_Book',(x,1.7,z+.04),(.8,.55,.08),'paper');stool('Reading_Stool',x,2.9,.55,'sage')
    locus(4);rug('Locus_04_Story_Rug',(5,1.25),(2.8,2.2),'teal')
    for x,y,c in [(4.3,1.8,'rose'),(5.5,1.8,'yellow'),(5,1,'mint')]:pillow('Story_Cushion',x,y,.2,c,(.9,.8,.35))
    locus(5);shelf('Locus_05_Return_Cart',5.2,-5.35,2.1,2,'books',1.4)
    for x in [4.4,6.0]:ball('Bookcart_Wheel',(x,-5.35,.14),(.14,.12,.14),'navy')
    finish('O')

def pumpkin(name,x,y,z=0,s=.6):
    for j in range(9):
        a=j*math.tau/9;ball(name+'_Lobe',(x+.28*s*math.cos(a),y+.28*s*math.sin(a),z+.6*s),(.52*s,.52*s,.60*s),'orange')
    beam(name+'_Stem',(x,y,z+1.05*s),(x+.1*s,y,z+1.4*s),.1*s,'leaf')

def P():
    start('P',floor_mat='grass',style='garden')
    for x in [-5,0,5]:
        box('Pumpkin_Patch',(x,4.9,.06),(3.4,2.8,.12),'soil')
        for dx,dy,s in [(-.8,-.6,.6),(.8,.5,.7),(.3,-.6,.5)]:pumpkin('Growing_Pumpkin',x+dx,4.9+dy,0,s)
        collider('Pumpkin_Patch',(x,4.9,.4),(3.4,2.8,.8))
    locus(1);board('Locus_01_Farm',-4.3,-4.8,'HARVEST TIME','Plant - grow - share')
    locus(2);shelf('Locus_02_Seeds',-5.1,1.1,2.7,2,'seeds',2.0)
    locus(3);z=table('Locus_03_Harvest',0,1.7,3,1.4,.9)
    for x,s in [(-.9,.45),(0,.55),(.9,.4)]:pumpkin('Sorted_Pumpkin',x,1.7,z,s)
    locus(4);sink('Locus_04_Irrigation',5,1.25)
    locus(5);z=table('Locus_05_Produce',5.2,-5.15,2.5,1, .85);pumpkin('Gift_Pumpkin',5.2,-5.15,z,.6)
    finish('P')

def Q():
    start('Q',wall='rose')
    # A large tactile patchwork creates a recognisable story pavilion.
    for i in range(9):
        for j in range(4):
            x=-5.6+i*1.4;z=.65+j*.65
            box('Story_Quilt_Patch',(x,6.65,z),(1.35,.1,.6),['teal','rose','yellow','mint','blue'][(i+j*2)%5],.05)
            ring('Quilt_Stitch',(x,6.58,z),.20,.012,'ivory',(math.pi/2,0,0),segments=20)
    locus(1);board('Locus_01_Cover',-4.3,-4.8,'ONCE UPON A TIME','Tell your own story',color='purple')
    locus(2);shelf('Locus_02_Fabric',-5.1,1.1,2.8,3,'yarn',2.1)
    locus(3);z=table('Locus_03_Quilting',0,1.7,3.3,1.7,.9)
    for i in range(4):
        for j in range(2):box('Work_Quilt',(-1.05+i*.7,1.35+j*.7,z+.03),(.67,.67,.05),['rose','mint','yellow','blue'][(i+j)%4],.03)
    locus(4);rug('Locus_04_Story_Circle',(5,1.25),(3,2.4),'purple')
    for x,y,c in [(4.3,1.7,'yellow'),(5.6,1.7,'rose'),(5,.7,'mint')]:pillow('Quilt_Cushion',x,y,.18,c,(.85,.75,.3))
    locus(5);shelf('Locus_05_Story_Albums',5.2,-5.3,2.3,2,'books',1.6)
    finish('Q')

def robot(name,x,y,z=0,s=1):
    box(name+'_Body',(x,y,z+1.0*s),(1*s,.65*s,1.1*s),'teal',.14*s)
    box(name+'_Head',(x,y,z+1.9*s),(1.15*s,.75*s,.85*s),'cream',.17*s)
    for dx in [-.27,.27]:ball(name+'_Eye',(x+dx*s,y-.4*s,z+1.98*s),(.14*s,.06*s,.14*s),'navy')
    box(name+'_Smile',(x,y-.4*s,z+1.72*s),(.40*s,.04*s,.05*s),'rose')
    for dx in [-.7,.7]:beam(name+'_Arm',(x+dx*.65*s,y,z+1.25*s),(x+dx*s,y,z+.75*s),.12*s,'metal');ball(name+'_Hand',(x+dx*s,y,z+.65*s),(.18*s,)*3,'yellow')
    for dx in [-.3,.3]:box(name+'_Foot',(x+dx*s,y-.12*s,z+.20*s),(.38*s,.7*s,.4*s),'metal')
    beam(name+'_Antenna',(x,y,z+2.3*s),(x,y,z+2.6*s),.035*s,'metal');ball(name+'_Antenna_Light',(x,y,z+2.63*s),(.10*s,)*3,'red')

def R():
    start('R',wall='blue',floor_mat='stone')
    box('Garage_Pegboard',(0,6.65,2),(10,.12,2),'oak')
    for i in range(20):
        x=-4.7+(i%10)*1.05;z=1.3+(i//10)*1
        ring('Tool_Ring',(x,6.55,z),.16,.045,'metal',(math.pi/2,0,0));beam('Tool_Handle',(x,6.55,z-.1),(x,6.55,z-.5),.05,'metal')
    locus(1);board('Locus_01_Repairs',-4.3,-4.8,'FIX IT TOGETHER','Look - plan - build')
    locus(2);shelf('Locus_02_Parts',-5.1,1.1,2.8,3,'jars',2.25)
    locus(3);z=table('Locus_03_Robot_Workbench',0,1.7,3.2,1.7,.9,'oak',True);robot('Friendly_Robot',0,1.7,z,.65)
    locus(4);z=table('Locus_04_Tools',5,1.25,2.7,1.3);box('Toolbox',(5,1.25,z+.28),(1.6,.65,.55),'red');beam('Toolbox_Handle',(4.5,1.25,z+.6),(5.5,1.25,z+.6),.055,'metal')
    locus(5);z=table('Locus_05_Delivery',5.2,-5.15,2.4,1, .8);robot('Repaired_Robot',5.2,-5.15,z,.5)
    finish('R')

def star_mesh(name,x,y,z,r=1,mat='yellow'):
    pts=[(x,y,z)]+[(x+math.sin(i*math.pi/5)*(r if i%2==0 else r*.45),y+math.cos(i*math.pi/5)*(r if i%2==0 else r*.45),z) for i in range(10)]
    return mesh(name,pts,[(0,i+1,(i+1)%10+1) for i in range(10)],mat)

def S():
    start('S',wall='navy',floor_mat='blue')
    star_mesh('Star_Observation_Floor',0,1.7,.02,5,'navy')
    for x,z,r in [(-6,2,.3),(-4,2.9,.2),(-2,1.8,.3),(1.5,2.5,.35),(4,2,.25),(6,2.9,.3)]:
        ob=star_mesh('Wall_Star',0,0,0,r);ob.rotation_euler[0]=math.pi/2;ob.location=(x,6.7,z)
    locus(1);board('Locus_01_Sky_Guide',-4.3,-4.8,'LOOK UP','A sky full of stories',color='navy')
    locus(2);shelf('Locus_02_Charts',-5.1,1.1,2.7,2,'books',2)
    locus(3);telescope('Locus_03_Telescope',0,1.7,0,1.25)
    locus(4);z=table('Locus_04_Notes',5,1.25,2.7,1.3);box('Sky_Journal',(5,1.25,z+.05),(1,.6,.1),'paper')
    locus(5);z=table('Locus_05_Orbits',5.2,-5.15,2.3,1.2,.9);ball('Sun_Model',(5.2,-5.15,z+.5),(.3,)*3,'yellow');ring('Orbit_Model',(5.2,-5.15,z+.5),.7,.02,'gold');ball('Planet_Model',(5.9,-5.15,z+.5),(.16,)*3,'blue')
    finish('S')

def T():
    start('T',floor_mat='sand',style='stone')
    # Train occupies the rear strip; all five passenger services face the forecourt.
    for y in [4.2,5.6]:beam('Rail',(-7,y,.08),(7,y,.08),.07,'metal')
    for x in range(-7,8):box('Rail_Sleeper',(x,4.9,.02),(.15,2.2,.08),'wood')
    box('Carriage_Body',(0,4.9,1.3),(8,2,2.3),'teal',.3)
    box('Carriage_Roof',(0,4.9,2.65),(8.4,2.3,.45),'darkwood',.22)
    for x in [-2.8,-1.4,0,1.4,2.8]:window('Carriage_Window',x,3.85,1.8,1,.9)
    for x in [-2.8,2.8]:
        for y in [4,5.8]:ob=cyl('Train_Wheel',(x,y,.45),.4,.2,'navy');ob.rotation_euler[0]=math.pi/2
    collider('Train',(0,4.9,1.3),(8.5,2.6,2.6))
    locus(1);board('Locus_01_Timetable',-4.3,-4.8,'DEPARTURES','Morning - noon - evening')
    locus(2);bench('Locus_02_Waiting',-5.1,1.1,2.6,'teal')
    locus(3);z=table('Locus_03_Tickets',0,1.7,2.8,1.1,1.05,'oak',True);box('Ticket_Machine',(0,1.7,z+.4),(.7,.6,.8),'teal');box('Ticket_Slot',(0,1.37,z+.35),(.4,.03,.07),'black')
    locus(4);shelf('Locus_04_Luggage',5,1.25,2.7,2,'parcels',1.9)
    locus(5);door('Locus_05_Platform',5.2,-5.45,'PLATFORM','teal');collider('Platform_Portal',(5.2,-5.45,1.4),(2.4,.4,2.8))
    finish('T')

def umbrella(name,x,y,z=2.7,r=1.6):
    cyl(name+'_Pole',(x,y,z/2),.06,z,'wood')
    for j in range(8):
        a=j*math.tau/8;b=(j+1)*math.tau/8
        mesh(name+'_Canopy',[(x,y,z+.7),(x+r*math.cos(a),y+r*math.sin(a),z),(x+r*math.cos(b),y+r*math.sin(b),z)],[(0,1,2)],'yellow' if j%2 else 'rose')
        beam(name+'_Rib',(x,y,z+.65),(x+r*math.cos(a),y+r*math.sin(a),z),.025,'lightwood')

def U():
    start('U',floor_mat='sand',style='garden')
    umbrella('Weather_Umbrella',0,5.0,3.2,2.3);collider('Umbrella_Pole',(0,5,.9),(.4,.4,1.8))
    for x in [-5,5]:garden_box('Rain_Garden',x,5,2.8,1.4)
    locus(1);board('Locus_01_Forecast',-4.3,-4.8,'WEATHER TODAY','Look outside first',color='blue')
    locus(2);shelf('Locus_02_Rain_Gear',-5.1,1.1,2.6,2,'none',2)
    for x in [-5.8,-5.1,-4.4]:cyl('Folded_Umbrella',(x,1.1,1),.13,1.6,'rose');ring('Umbrella_Handle',(x,1.1,1.9),.14,.04,'wood',(math.pi/2,0,0),.6)
    locus(3);z=table('Locus_03_Weather_Lab',0,1.7,3,1.4,.9);beam('Wind_Mast',(0,1.7,z),(0,1.7,z+1.7),.04,'metal');beam('Wind_Arrow',(-.6,1.7,z+1.5),(.6,1.7,z+1.5),.04,'gold');cyl('Rain_Gauge',(-.8,1.7,z+.4),.17,.8,'glass')
    locus(4);z=table('Locus_04_Log',5,1.25,2.6,1.2);box('Weather_Log',(5,1.25,z+.05),(1.1,.7,.1),'paper')
    locus(5);board('Locus_05_Plans',5.2,-5.15,'READY TO GO','Coat - hat - umbrella',color='teal')
    finish('U')

def volcano(name,x,y,z=0,s=1):
    cyl(name+'_Mountain',(x,y,z+.85*s),1.6*s,1.7*s,'rock',32,top=.68*s)
    cyl(name+'_Crater',(x,y,z+1.72*s),.61*s,.03,'darkwood',32)
    ring(name+'_Rim',(x,y,z+1.7*s),.67*s,.12*s,'stone')
    for i in range(7):
        a=i*math.tau/7;ball(name+'_Stone',(x+1.05*s*math.cos(a),y+1.05*s*math.sin(a),z+.55*s),(.55*s,.4*s,.45*s),'stone')

def V():
    start('V',floor_mat='sand',style='stone')
    volcano('Dormant_Volcano_Backdrop',0,4.9,0,1.7);collider('Volcanic_Rock_Ridge',(0,4.9,1.4),(5.5,4.7,2.8))
    for x in [-5.7,5.7]:ball('Field_Boulder',(x,5.2,.65),(1.1,.8,.65),'rock')
    locus(1);board('Locus_01_Trail',-4.3,-4.8,'ROCK EXPLORERS','Look closely - tread gently')
    locus(2);shelf('Locus_02_Specimens',-5.1,1.1,2.8,2,'none',2)
    for x in [-5.9,-5.1,-4.3]:ball('Rock_Sample',(x,1.1,.7),(.25,.23,.25),'rock');ball('Crystal_Sample',(x,1.1,1.6),(.20,.16,.3),'blue',8,4)
    locus(3);z=table('Locus_03_Volcano_Model',0,1.7,3,1.7,.9);volcano('Volcano_Model',0,1.7,z,.65)
    locus(4);z=table('Locus_04_Field_Tools',5,1.25,2.6,1.3);ring('Hand_Lens',(5,1.25,z+.1),.35,.05,'gold');beam('Geologist_Hammer',(4.5,1,z+.1),(5.4,1.5,z+.1),.07,'wood');box('Hammer_Head',(5.4,1.5,z+.12),(.5,.25,.25),'metal')
    locus(5);z=table('Locus_05_Finds',5.2,-5.15,2.3,1,.9);ball('Favourite_Rock',(5.2,-5.15,z+.3),(.5,.35,.3),'stone')
    finish('V')

def whale(name,x,y,z,s=1):
    ball(name+'_Body',(x,y,z),(2.1*s,.75*s,.85*s),'blue',32,20)
    ball(name+'_Belly',(x-.3*s,y-.48*s,z-.3*s),(1.5*s,.35*s,.45*s),'glass')
    for dy in [-.45,.45]:ob=ball(name+'_Tail',(x+2.1*s,y+dy*s,z+.3*s),(.65*s,.65*s,.15*s),'teal');ob.rotation_euler[1]=-.3
    ob=ball(name+'_Flipper',(x,y-.65*s,z-.4*s),(.65*s,.45*s,.12*s),'teal');ob.rotation_euler[1]=-.5
    ball(name+'_Eye',(x-1.4*s,y-.65*s,z+.1*s),(.09*s,)*3,'navy')

def W():
    start('W',wall='blue',floor_mat='sand')
    box('Ocean_Panorama',(0,6.62,1.85),(13,.12,2.9),'water',.2)
    whale('Whale_Exhibit',0,5.0,2.6,1.25)
    box('Rear_Marine_Pool',(0,5.1,.25),(12,2.5,.5),'teal',.2);box('Marine_Water',(0,5.1,.52),(11.6,2.2,.04),'water');collider('Marine_Pool',(0,5.1,.9),(12,2.6,1.8))
    locus(1);board('Locus_01_Ocean_Guide',-4.3,-4.8,'HELLO OCEAN','A world below the waves')
    locus(2);shelf('Locus_02_Shells',-5.1,1.1,2.7,2,'none',2)
    for x in [-5.9,-5.1,-4.3]:ball('Shell',(x,1.1,.65),(.27,.17,.20),'pink');ring('Shell_Spiral',(x,1,1.55),.2,.065,'cream',(math.pi/2,0,0),.9)
    locus(3);z=table('Locus_03_Tidepool',0,1.7,3.2,1.8,.78,'teal',True);box('Tidepool_Water',(0,1.7,z+.04),(2.8,1.4,.06),'water');star_mesh('Starfish',.5,1.7,z+.09,.27,'rose');ball('Tidepool_Rock',(-.8,1.7,z+.2),(.4,.3,.2),'stone')
    locus(4);box('Locus_04_Aquarium',(5,1.25,1.0),(2.7,1.5,1.7),'water',.15);box('Aquarium_Base',(5,1.25,.2),(2.8,1.6,.4),'teal');collider('Aquarium',(5,1.25,1),(2.9,1.7,2))
    for x in [4.3,5.2,5.8]:ball('Fish',(x,.42,1.1),(.25,.07,.14),'yellow');ball('Fish_Eye',(x-.15,.34,1.14),(.025,)*3,'navy')
    locus(5);shelf('Locus_05_Sea_Albums',5.2,-5.3,2.3,2,'books',1.6)
    finish('W')

def X():
    start('X',floor_mat='oak',style='water')
    box('Stage_Back_Sea',(0,5.4,.01),(14,2.8,.025),'water');collider('Sea_Backdrop',(0,5.4,.6),(14,2.8,1.2))
    for x in [-6.5,6.5]:beam('Stage_Pole',(x,4,0),(x,4,3.7),.08,'wood')
    beam('Festival_Light_String',(-6.5,4,3.7),(6.5,4,3.7),.02,'wood')
    for j in range(9):lantern('Stage_Lantern',-5.6+j*1.4,4,3.3,'yellow',.22)
    locus(1);board('Locus_01_Programme',-4.3,-4.8,'SEASIDE MUSIC','Make a melody together')
    locus(2);shelf('Locus_02_Mallets',-5.1,1.1,2.6,2,'none',2)
    for x in [-5.9,-5.1,-4.3]:beam('Mallet_Handle',(x,1.1,.4),(x,1.1,1.5),.035,'oak');ball('Mallet_Head',(x,1.1,1.6),(.16,)*3,'rose')
    locus(3);z=table('Locus_03_Xylophone',0,1.7,4.2,2.0,.85,'darkwood')
    for i in range(9):
        x=-1.75+i*.43;box('Xylophone_Key',(x,1.7,z+.08),(.38,1.7-i*.09,.16),['rose','orange','yellow','mint','teal','blue','purple','rose','yellow'][i]);
        for y in [1.4,2]:ball('Key_Pin',(x,y,z+.18),(.025,)*3,'gold')
    locus(4);bench('Locus_04_Rehearsal',5,1.25,2.6,'teal')
    locus(5);board('Locus_05_Performances',5.2,-5.15,'OUR CONCERTS','Every part matters',color='rose')
    finish('X')

def Y():
    start('Y',wall='lavender')
    for x in [-5,0,5]:shelf('Yarn_Wall',x,5.9,3.3,3,'yarn',2.5)
    locus(1);board('Locus_01_Patterns',-4.3,-4.8,'MADE WITH LOVE','Choose - knit - give',color='purple')
    locus(2);shelf('Locus_02_Yarn',-5.1,1.1,2.8,3,'yarn',2.4)
    locus(3);rug('Knitting_Rug',(0,1.7),(4.4,3.4),'rose');z=table('Locus_03_Knitting',0,1.7,3,1.5,.8)
    for x,col in [(-.8,'yellow'),(.5,'mint')]:yarn('Work_Yarn',x,1.7,z+.38,.38,col)
    beam('Knitting_Needle',(-.4,1.2,z+.1),(.9,2,z+.3),.025,'lightwood');beam('Knitting_Needle',(-.3,2,z+.1),(.9,1.2,z+.3),.025,'lightwood')
    locus(4);z=table('Locus_04_Wrapping',5,1.25,2.7,1.3);parcel('Knitted_Gift',5,1.25,z+.3,.9,'rose')
    locus(5);shelf('Locus_05_Handmade',5.2,-5.3,2.3,2,'parcels',1.7)
    finish('Y')

def Z():
    start('Z',wall='cream')
    for x in range(-7,8):box('Zebra_Stripe',(x,6.75,2.0),(.38,.04,3.3),'darkwood',.015)
    for x in [-5,0,5]:shelf('Mail_Sorting_Wall',x,5.95,3.3,3,'parcels',2.5)
    locus(1);board('Locus_01_Post_Guide',-4.3,-4.8,'LETTERS CONNECT US','Write - wrap - send')
    locus(2);shelf('Locus_02_Letters',-5.1,1.1,2.8,3,'books',2.3)
    locus(3);z=table('Locus_03_Packing',0,1.7,3.2,1.6);parcel('Parcel_To_Send',0,1.7,z+.4,1.1,'paper');ring('Packing_Tape',(1,1.7,z+.1),.22,.07,'yellow')
    locus(4);z=table('Locus_04_Scale',5,1.25,2.5,1.2);box('Parcel_Scale',(5,1.25,z+.18),(1.1,.8,.36),'teal');cyl('Scale_Plate',(5,1.25,z+.4),.6,.08,'metal');parcel('Weighed_Parcel',5,1.25,z+.65,.65,'rose')
    locus(5);box('Locus_05_Postbox',(5.2,-5.15,.9),(1.4,1.1,1.8),'teal',.18);box('Postbox_Slot',(5.2,-5.73,1.3),(.85,.04,.12),'navy');text('Postbox_Label','POST',(5.2,-5.76,.8),.28);collider('Postbox',(5.2,-5.15,.9),(1.5,1.2,1.8))
    finish('Z')

RECIPES={k:globals()[k] for k in NAMES}
