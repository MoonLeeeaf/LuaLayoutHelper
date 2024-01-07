require "import"
import "android.app.*"
import "android.os.*"
import "java.io.*"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "com.androlua.*"

axh = require "alyxmlhelper"

layoutisxml = false
layoutfile = activity.getLuaDir("tmp.txt")

local _luajava_bindClass = luajava.bindClass
luajava.bindClass = function(name)
  return ({xpcall(function(name)
      return _luajava_bindClass(name)
      end,function(e)
      print(e)
      return LinearLayout
  end,name)})[2]
end

layout={
  main={
    LinearLayout,
    orientation="vertical",
  },

  ck={
    LinearLayout;
    {
      RadioGroup;
      layout_weight="1";
      id="ck_rg";
    };
    {
      Button;
      Text="确定";
      layout_gravity="right";
      id="ck_bt";
    };
    orientation="vertical";
  };
}

function getFileUri(intent)
  local data = intent.getData();
  if (data ~= nil)
    local path = data.getPath();
    if (path ~= null)
      if ("content" == (data.getScheme()))
        local ins = activity.getContentResolver().openInputStream(data);
        local path2 = activity.getLuaExtPath("cache", File(data.getPath()).getName());
        local out = FileOutputStream(path2);
        LuaUtil.copyFile(ins, out);
        out.close();
        return (path2);
      end
      local idx = path.indexOf("/storage/emulated/");
      if (idx > 0)
        path = path.substring(idx);
      end
      return (path);
    end
  end
end

luapath=layoutfile --getDataFile() or ""
luadir=luajava.luadir or luapath:gsub("/[^/]+$","")

package.path=package.path..";"..luadir.."/?.lua;"

import "loadlayout2"
require "xml2table"

showsave=true

--if luapath:find("%.aly$") then
local f=io.open(luapath)
local s=f:read("*a")
f:close()
xpcall(function()
  layout.main=assert(loadstring("return "..s))()
end,
function()
  --Toast.makeText(activity,"布局错误或导入包不存在",1000).show()
  --activity.finish()
end)
--showsave=true
--end

--[[if luapath:find("%.xml") then
  local f=io.open(luapath)
  local s=f:read("*a")
  f:close()
  s = axh.parseXmlToAly(s)
  xpcall(function()
    layout.main=assert(loadstring("return "..s))()
  end,
  function()
    Toast.makeText(activity,"布局错误或导入包不存在",1000).show()
    activity.finish()
  end)
  showsave=true
end]]

function onTouch(v,e)
  if e.getAction() == MotionEvent.ACTION_DOWN then
    getCurr(v)
    return true
  end
end

local TypedValue=luajava.bindClass("android.util.TypedValue")
local dm=activity.getResources().getDisplayMetrics()
function dp(n)
  return TypedValue.applyDimension(1,n,dm)
end

function to(n)
  return string.format("%ddp",n//dn)
end

dn=dp(1)
lastX=0
lastY=0
vx=0
vy=0
vw=0
vh=0
zoomX=false
zoomY=false
function move(v,e)
  curr=v.Tag
  currView=v
  ry=e.getRawY()--获取触摸绝对Y位置
  rx=e.getRawX()--获取触摸绝对X位置
  if e.getAction() == MotionEvent.ACTION_DOWN then
    lp=v.getLayoutParams()
    vy=v.getY()--获取视图的Y位置
    vx=v.getX()--获取视图的X位置
    lastY=ry--记录按下的Y位置
    lastX=rx--记录按下的X位置
    vw=v.getWidth()--记录控件宽度
    vh=v.getHeight()--记录控件高度
    if vw-e.getX()<20 then
      zoomX=true--如果触摸右边缘启动缩放宽度模式
     elseif vh-e.getY()<20 then
      zoomY=true--如果触摸下边缘启动缩放高度模式
    end

   elseif e.getAction() == MotionEvent.ACTION_MOVE then
    --lp.gravity=Gravity.LEFT|Gravity.TOP --调整控件至左上角
    if zoomX then
      lp.width=(vw+(rx-lastX))--调整控件宽度
     elseif zoomY then
      lp.height=(vh+(ry-lastY))--调整控件高度
     else
      lp.x=(vx+(rx-lastX))--移动的相对位置
      lp.y=(vy+(ry-lastY))--移动的相对位置
    end
    v.setLayoutParams(lp)--调整控件到指定的位置
    --v.Parent.invalidate()
   elseif e.getAction() == MotionEvent.ACTION_UP then
    if (rx-lastX)^2<100 and (ry-lastY)^2<100 then
      getCurr(v)
     else
      curr.layout_x=to(v.getX())
      curr.layout_y=to(v.getY())
      if zoomX then
        curr.layout_width=to(v.getWidth())
       elseif zoomY then
        curr.layout_height=to(v.getHeight())
      end
    end
    zoomX=false--初始化状态
    zoomY=false--初始化状态
  end
  return true
end

function getCurr(v)
  curr=v.Tag
  currView=v
  fd_dlg.setView(View(activity))
  fd_dlg.Title=tostring(v.Class.getName())
  if luajava.instanceof(v,GridLayout) then
    fd_dlg.setItems(fds_grid)
   elseif luajava.instanceof(v,LinearLayout) then
    fd_dlg.setItems(fds_linear)
   elseif luajava.instanceof(v,ViewGroup) then
    fd_dlg.setItems(fds_group)
   elseif luajava.instanceof(v,TextView) then
    fd_dlg.setItems(fds_text)
   elseif luajava.instanceof(v,ImageView) then
    fd_dlg.setItems(fds_image)
   else
    fd_dlg.setItems(fds_view)
  end
  if luajava.instanceof(v.Parent,LinearLayout) then
    fd_list.getAdapter().add("layout_weight")
   elseif luajava.instanceof(v.Parent,AbsoluteLayout) then
    fd_list.getAdapter().insert(5,"layout_x")
    fd_list.getAdapter().insert(6,"layout_y")
   elseif luajava.instanceof(v.Parent,RelativeLayout) then
    local adp=fd_list.getAdapter()
    for k,v in ipairs(relative) do
      adp.add(v)
    end
  end
  fd_dlg.show()
end

function adapter(t)
  local ls=ArrayList()
  for k,v in ipairs(t) do
    ls.add(v)
  end
  return ArrayAdapter(activity,android.R.layout.simple_list_item_1, ls)
end

import "android.graphics.drawable.*"


curr=nil
activity.setTitle('布局助手')
activity.setTheme(android.R.style.Theme_DeviceDefault)
--activity.Theme=android.R.style.Theme_Material_Light
xpcall(function()
  activity.setContentView(loadlayout2(layout.main,{}))
end,
function()
  --Toast.makeText(activity,"不支持编辑该布局",1000).show()
  --activity.finish()
end)

relative={
  "layout_above","layout_alignBaseline","layout_alignBottom","layout_alignEnd","layout_alignLeft","layout_alignParentBottom","layout_alignParentEnd","layout_alignParentLeft","layout_alignParentRight","layout_alignParentStart","layout_alignParentTop","layout_alignRight","layout_alignStart","layout_alignTop","layout_alignWithParentIfMissing","layout_below","layout_centerHorizontal","layout_centerInParent","layout_centerVertical","layout_toEndOf","layout_toLeftOf","layout_toRightOf","layout_toStartOf"
}

--属性列表对话框
fd_dlg=AlertDialogBuilder(activity)
fd_list=fd_dlg.getListView()
fds_grid={
  "添加","删除","父控件","子控件",
  "id","orientation",
  "columnCount","rowCount",
  "layout_width","layout_height","layout_gravity",
  "background","gravity",
  "layout_margin","layout_marginLeft","layout_marginTop","layout_marginRight","layout_marginBottom",
  "padding","paddingLeft","paddingTop","paddingRight","paddingBottom",
}

fds_linear={
  "添加","删除","父控件","子控件",
  "id","orientation","layout_width","layout_height","layout_gravity",
  "background","gravity",
  "layout_margin","layout_marginLeft","layout_marginTop","layout_marginRight","layout_marginBottom",
  "padding","paddingLeft","paddingTop","paddingRight","paddingBottom",
}

fds_group={
  "添加","删除","父控件","子控件",
  "id","layout_width","layout_height","layout_gravity",
  "background","gravity",
  "layout_margin","layout_marginLeft","layout_marginTop","layout_marginRight","layout_marginBottom",
  "padding","paddingLeft","paddingTop","paddingRight","paddingBottom",
}

fds_text={
  "删除","父控件",
  "id","layout_width","layout_height","layout_gravity",
  "background","text","hint","textColor","textSize","singleLine","gravity",
  "layout_margin","layout_marginLeft","layout_marginTop","layout_marginRight","layout_marginBottom",
  "padding","paddingLeft","paddingTop","paddingRight","paddingBottom",
}

fds_image={
  "删除","父控件",
  "id","layout_width","layout_height","layout_gravity",
  "background","src","scaleType","gravity",
  "layout_margin","layout_marginLeft","layout_marginTop","layout_marginRight","layout_marginBottom",
  "padding","paddingLeft","paddingTop","paddingRight","paddingBottom",
}

fds_view={
  "删除","父控件",
  "id","layout_width","layout_height","layout_gravity",
  "background","gravity",
  "layout_margin","layout_marginLeft","layout_marginTop","layout_marginRight","layout_marginBottom",
  "padding","paddingLeft","paddingTop","paddingRight","paddingBottom",
}

--属性选择列表
checks={}
checks.singleLine={"true","false"}
checks.orientation={"vertical","horizontal"}
checks.gravity={"left","top","right","bottom","start","center","end"}
checks.layout_gravity={"left","top","right","bottom","start","center","end"}
checks.scaleType={
  "matrix",
  "fitXY",
  "fitStart",
  "fitCenter",
  "fitEnd",
  "center",
  "centerCrop",
  "centerInside"}


function addDir(out,dir,f)
  local ls=f.listFiles()
  for n=0,#ls-1 do
    local name=ls[n].getName()
    if ls[n].isDirectory() then
      addDir(out,dir..name.."/",ls[n])
     elseif name:find("%.j?pn?g$") then
      table.insert(out,dir..name)
    end
  end
end

function checkid()
  local cs={}
  local parent=currView.Parent.Tag
  for k,v in ipairs(parent) do
    if v==curr then
      break
    end
    if type(v)=="table" and v.id then
      table.insert(cs,v.id)
    end
  end
  return cs
end

rbs={"layout_alignParentBottom","layout_alignParentEnd","layout_alignParentLeft","layout_alignParentRight","layout_alignParentStart","layout_alignParentTop","layout_centerHorizontal","layout_centerInParent","layout_centerVertical"}
ris={"layout_above","layout_alignBaseline","layout_alignBottom","layout_alignEnd","layout_alignLeft","layout_alignRight","layout_alignStart","layout_alignTop","layout_alignWithParentIfMissing","layout_below","layout_toEndOf","layout_toLeftOf","layout_toRightOf","layout_toStartOf"}
for k,v in ipairs(rbs) do
  checks[v]={"true","false","none"}
end

for k,v in ipairs(ris) do
  checks[v]=checkid
end

if luadir then
  checks.src=function()
    local src={}
    addDir(src,"",File(luadir))
    return src
  end
end

fd_list.onItemClick=function(l,v,p,i)
  fd_dlg.hide()
  local fd=tostring(v.Text)
  if checks[fd] then
    if type(checks[fd])=="table" then
      check_dlg.Title=fd
      check_dlg.setItems(checks[fd])
      check_dlg.show()
     else
      check_dlg.Title=fd
      check_dlg.setItems(checks[fd](fd))
      check_dlg.show()
    end
   else
    func[fd]()
  end
end

--子视图列表对话框
cd_dlg=AlertDialogBuilder(activity)
cd_list=cd_dlg.getListView()
cd_list.onItemClick=function(l,v,p,i)
  getCurr(chids[p])
  cd_dlg.hide()
end

--可选属性对话框
check_dlg=AlertDialogBuilder(activity)
check_list=check_dlg.getListView()
check_list.onItemClick=function(l,v,p,i)
  local v=tostring(v.Text)
  if #v==0 or v=="none" then
    v=nil
  end
  local fld=check_dlg.Title
  local old=curr[tostring(fld)]
  curr[tostring(fld)]=v
  check_dlg.hide()
  local s,l=pcall(loadlayout2,layout.main,{})
  if s then
    activity.setContentView(l)
   else
    curr[tostring(fld)]=old
    print(l)
  end
end

func={}
setmetatable(func,{__index=function(t,k)
    return function()
      sfd_dlg.Title=k--tostring(currView.Class.getSimpleName())
      --sfd_dlg.Message=k
      fld.Text=curr[k] or ""
      sfd_dlg.show()
    end
  end
})
func["添加"]=function()
  add_dlg.Title=tostring(currView.Class.getName())
  for n=0,#ns-1 do
    if n~=i then
      el.collapseGroup(n)
    end
  end
  add_dlg.show()
end

func["删除"]=function()
  AlertDialogBuilder()
  .setTitle("确定要删除吗？")
  .setMessage(currView.getClass().getName())
  .setPositiveButton("确定",{onClick=function()
      local gp=currView.Parent.Tag
      if gp==nil then
        Toast.makeText(activity,"不可以删除顶部控件",1000).show()
        return
      end
      for k,v in ipairs(gp) do
        if v==curr then
          table.remove(gp,k)
          break
        end
      end
      activity.setContentView(loadlayout2(layout.main,{}))
  end})
  .setNegativeButton("取消",nil)
  .show()
end


func["父控件"]=function()
  local p=currView.Parent
  if p.Tag==nil then
    Toast.makeText(activity,"已是顶部控件",1000).show()
   else
    getCurr(p)
  end
end

chids={}
func["子控件"]=function()
  chids={}
  local arr={}
  for n=0,currView.ChildCount-1 do
    local chid=currView.getChildAt(n)
    chids[n]=chid
    table.insert(arr,chid.Class.getName())
  end
  cd_dlg.Title=tostring(currView.Class.getName())
  cd_dlg.setItems(arr)
  cd_dlg.show()
end

--添加视图对话框
add_dlg=Dialog(activity)
add_dlg.Title="添加"
wdt_list=ListView(activity)

ns={
  "控件","开关组件","列表适配器","高级控件","布局","高级布局",
}

wds={
  {"Button","EditText","TextView",
    "ImageButton","ImageView"},
  {"CheckBox","RadioButton","ToggleButton","Switch"},
  {"ListView","GridView","PageView","ExpandableListView","Spinner"},
  {"SeekBar","ProgressBar","RatingBar",
    "DatePicker","TimePicker","NumberPicker"},
  {"LinearLayout","AbsoluteLayout","FrameLayout","RelativeLayout"},
  {"CardView","RadioGroup","GridLayout",
    "ScrollView","HorizontalScrollView"},
}


mAdapter=ArrayExpandableListAdapter(activity)
for k,v in ipairs(ns) do
  mAdapter.add(v,wds[k])
end

el=ExpandableListView(activity)
el.setAdapter(mAdapter)
add_dlg.setContentView(el)

el.onChildClick=function(l,v,g,c)
  local w={_G[wds[g+1][c+1]]}
  table.insert(curr,w)
  local s,l=pcall(loadlayout2,layout.main,{})
  if s then
    activity.setContentView(l)
   else
    table.remove(curr)
    print(l)
  end
  add_dlg.hide()
end



function ok()
  local v=tostring(fld.Text)
  if #v==0 then
    v=nil
  end
  local fld=sfd_dlg.Title
  local old=curr[tostring(fld)]
  curr[tostring(fld)]=v
  --sfd_dlg.hide()
  local s,l=pcall(loadlayout2,layout.main,{})
  if s then
    activity.setContentView(l)
   else
    curr[tostring(fld)]=old
    print(l)
  end
end

function none()
  local old=curr[tostring(sfd_dlg.Title)]
  curr[tostring(sfd_dlg.Title)]=nil
  --sfd_dlg.hide()
  local s,l=pcall(loadlayout2,layout.main,{})
  if s then
    activity.setContentView(l)
   else
    curr[tostring(sfd_dlg.Title)]=old
    print(l)
  end
end


--输入属性对话框
sfd_dlg=AlertDialogBuilder(activity)
fld=EditText(activity)
sfd_dlg.setView(fld)
sfd_dlg.setTitle("属性")
sfd_dlg.setPositiveButton("确定",{onClick=ok})
sfd_dlg.setNegativeButton("取消",nil)
sfd_dlg.setNeutralButton("典型值",nil)
sfd_dlg.create().getButton(DialogInterface.BUTTON_NEUTRAL).setOnClickListener({onClick=function(v)
    local p = PopupMenu(this,v)
    local m = p.menu
    m.add("")
    m.add("match_parent")
    m.add("wrap_content")
    m.add("10dp")
    m.add("0xffffffff")
    p.onMenuItemClick = function(mi)
      local t = mi.title
      fld.text = t
    end
    p.show()
end})
function dumparray(arr)
  local ret={}
  table.insert(ret,"{\n")
  for k,v in ipairs(arr) do
    table.insert(ret,string.format("\"%s\";\n",v))
  end
  table.insert(ret,"};\n")
  return table.concat(ret)
end
function dumplayout(t)
  table.insert(ret,"{\n")
  table.insert(ret,"luajava.bindClass(\"" .. tostring(t[1].getName().."\");\n"))
  for k,v in pairs(t) do
    if type(k)=="number" then
      --do nothing
     elseif type(v)=="table" then
      table.insert(ret,k.."="..dumparray(v))
     elseif type(v)=="string" then
      if v:find("[\"\'\r\n]") then
        table.insert(ret,string.format("%s=[==[%s]==];\n",k,v))
       else
        table.insert(ret,string.format("%s=\"%s\";\n",k,v))
      end
     else
      table.insert(ret,string.format("%s=%s;\n",k,tostring(v)))
    end
  end
  for k,v in ipairs(t) do
    if type(v)=="table" then
      dumplayout(v)
    end
  end
  table.insert(ret,"};\n")
end

function dumplayout2(t)
  ret={}
  dumplayout(t)
  return table.concat(ret)
end

function onCreateOptionsMenu(menu)
  menu.add("打开")
  menu.add("复制")
  menu.add("编辑")
  menu.add("预览")
  --menu.add("外控")
  if showsave then
    menu.add("保存")
  end
  menu.add("关于")
end

function save(s)
  local s = s
  if layoutisxml then
    s = axh.parseAlyToXml(s)
  end
  local f=io.open(layoutfile,"w")
  f:write(s)
  f:close()
end

import "android.content.*"
cm=activity.getSystemService(activity.CLIPBOARD_SERVICE)

import "hisuzume.utils.FileUtils"
import "hisuzume.utils.*"

function onMenuItemSelected(id,item)
  local t=item.getTitle()
  if t=="复制" then
    local cd = ClipData.newPlainText("label",dumplayout2(layout.main))
    cm.setPrimaryClip(cd)
    Toast.makeText(activity,"已复制到剪切板",1000).show()
   elseif t=="编辑" then
    editlayout(dumplayout2(layout.main))
   elseif t=="预览" then
    show(dumplayout2(layout.main))
   elseif t=="保存" then
    save(dumplayout2(layout.main))
    Toast.makeText(activity,"已保存",1000).show()
    --activity.setResult(10000,Intent());
    --activity.finish()
   elseif t=="关于" then
    AlertDialogBuilder()
    .setTitle("关于 布局助手")
    .setMessage("本工具由 nirenr 制作，由 HiSuzume 修改，也就成了现在的模样。\n\n虽然这个工具还有些不完善，但是嘛，能用就行，只要人还在，代码就能跑。\n\nps：目前还不支持自定义控件的编辑，毕竟 Lua 以及这个工具本身的特性就已经限制了我的发挥，不过问题始终都会被解决的！\n\nGithub: https://github.com/HelloSuzume/LuaLayoutHelper")
    .setPositiveButton("关闭",nil)
    .show()
   elseif t=="打开" then
    local intent = Intent(Intent.ACTION_OPEN_DOCUMENT);
    intent.addCategory(Intent.CATEGORY_OPENABLE);
    intent.setType("*/*");
    activity.startActivityForResult(intent, 114514);
  end
end

function onActivityResult(req,res,d)
  if (req == 114514 and res == Activity.RESULT_OK) then
    local p = FileUtils.getFilePathFromSAFUri(this,d.getData())
    local l = io.open(p,"r"):read("*a")
    local f,er
    if p:find("%.xml") then
      f,er = load("return " .. axh.parseXmlToAly(l))
      layoutisxml = true
     elseif p:find("%.aly") then
      f,er = load("return " .. (l))
      layoutisxml = false
     else
      FastToast.shortToast(this,"这文件不对路吧？")
      return
    end
    layoutfile = p
    if er then
      activity.showToast(er)
     else
      layout.main = f()
      activity.setContentView(loadlayout2(layout.main,{}))
    end
  end
end

function onStart()
  activity.setContentView(loadlayout2(layout.main,{}))
end

lastclick=os.time()-2
function onKeyDown(e)
  local now=os.time()
  if e==4 then
    if now-lastclick>2 then
      Toast.makeText(activity, "再按一次返回.", Toast.LENGTH_SHORT ).show()
      lastclick=now
      return true
    end
  end
end


