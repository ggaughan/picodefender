pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
debug = true

ww = 128 * 9
cx = 128 * 4
ocx = cx
w = {}  -- ground
sw = {} -- ground summary

inertia_py = 0.95
inertia_cx = 0.99


hc = 128/4
hudy=12  -- = hudh
hudw=hc*2
hwr = ww/hudw
hhr = (128-4 - hudy)/hudy + 1
lmin = 3
lmax = 56

cdx = 0
max_speed = 4
thrust = 1
vert_accel = 0.6
max_vert_speed = max_speed/2

function _init()
	build_world()
	
	pl = {
		x=64,
		y=64,
		
		facing=1,
		dx=0,
		dy=0,
	}

end



-->8
function _update60()
 if btnp(⬅️) then
	 pl.facing = -1*pl.facing
	 -- start animation?
  cdx = cdx * 0.5
  -- plus pl.dx
	end
 if btn(➡️) then
  cdx = min(cdx+thrust,max_speed)
  -- plus pl.dx
 end
 if btn(⬆️) then
  pl.dy = pl.dy-vert_accel
  if (pl.dy < -max_vert_speed) pl.dy=-max_vert_speed
 end
 if btn(⬇️) then
  pl.dy = pl.dy+vert_accel
  if (pl.dy > max_vert_speed) pl.dy=max_vert_speed
 end
 
 pl.dy *= inertia_py
 pl.y += pl.dy 
 
 cx += cdx * pl.facing
 cdx *= inertia_cx
 if cx<0 then
 	cx = ww
 elseif cx > ww then
  cx = 0
 end
 if pl.y<hudy then
 	pl.y = hudy
 	pl.dy = 0
 elseif pl.y > 120 then
  pl.y = 120
 	pl.dy = 0
 end

end
-->8

function wtos(wx,wy)
	x=hc + ((ocx + wx )\hwr) % hudw
	y=wy\hhr
	return x,y
end

function draw_hud()
 local hdc = hudw/9
 
 -- ground
	for x = 0,hudw-1 do
		i = (x + (ocx + 128 + cx)\hwr) % hudw + 1
		pset(hc+x,hudy - (sw[i]), 4)
	end
	
	-- player
	sx,sy = wtos(pl.x, pl.y)
	pset(sx,sy, 8)

	-- scanner box 
	rect(hc,0, hc+hudw,hudy, 4)
	line(0,hudy,127,hudy, 4)
	line(hc+hdc*4-1,0, hc+hdc*5+1,0, 7)
	pset(hc+hdc*4-1,1, 7)
	pset(hc+hdc*5+1,1, 7)
	line(hc+hdc*4-1,hudy, hc+hdc*5+1,hudy, 7)
	pset(hc+hdc*4-1,hudy-1, 7)
 pset(hc+hdc*5+1,hudy-1, 7)

end

function _draw()
 cls()

	draw_hud()

	-- draw_ground	
	for x = 0,127 do
		i = ((ceil(cx+x))%ww) + 1
		printh(i)
		pset(x,127 - w[i][1], 4)
	end

	-- draw_player
	spr(2, pl.x, pl.y, 1,1, pl.facing==-1)
	
	if debug then
		print(cx,1,1)
		print(cdx,1,7)
	end

end


-->8
function build_world()
 local l = 10
 local ldy = 1
 local ls = nil
 local ll = nil
	for i = 1,ww do
	 local r = rnd()
	 
	 if r > 0.8 then
	 	ldy = 1
	 elseif r < 0.2 then
	  ldy = -1
	 else
	 	if r > 0.79 or r < 0.21 then
		 	ldy = -1 * ldy
		 end
	 end
	 
	 if ldy > 0 then
	  if l <= lmax then
   	l += 1
		 else
		 	ldy = -1
		 end
	 elseif ldy < 0 then
	 	if l >= lmin then
 	  l -= 1	
		 else 
		  ldy = 1
		 end
	 end
	 
	 if i % hwr == 0 then
   ls = ll
   ll = ceil(l/hhr)  -- pre-calc
   if ls and abs(ll - ls) > 1 then
    -- patch any holes
   	if ll - ls < 0 then
	   	ll = ll + 1
   	else
	   	ll = ll - 1
   	end
   end
	 	sw[i \ hwr] = ll
	 end

	 -- todo make ends meet!	 
		w[i] = {l}
	end
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000d000000e666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000dddd19006e66661000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000e73dd73eee6666b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
