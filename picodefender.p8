pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

ww = 128 * 9
cx = 128 * 4
w = {}  -- ground
sw = {} -- ground summary

hudy=12  -- = hudh
hudw=(128/4)*2
hwr = ww/hudw
hhr = (128-2 - hudy)/hudy
lmin = 3
lmax = 24

cdx = 0
max_speed = 4

function _init()
	build_world()
	
	pl = {
		x=64,
		y=64,
		
		facing=1,
	}

end



-->8
function _update60()
 if btnp(⬅️) then
	 pl.facing = -1*pl.facing
	 -- start animation?
  cdx = min(0,0)
	end
 if btnp(➡️) then
  cdx = max(cdx+1,max_speed)
 end
 
 
 cx += cdx * pl.facing
 
 if cx<0 then
 	cx = ww
 elseif cx > ww then
  cx = 0
 end
end
-->8

function draw_hud()
 local hc = 128/4
 local hdc = hudw/9
 
	for x = 0,hudw-1 do
		i = (((cx+x)\hwr)%hudw) + 1
		--printh(cx+x.." "..i)
		--printh(i..":"..sw[i])
		pset(128/4+x,hudy - sw[i], 4)
	end
 
	rect(hc,0, hc+hudw,hudy, 4)
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
		i = ((cx+x)%ww) + 1
		pset(x,127 - w[i][1], 4)
	end

	-- draw_player
	spr(2, pl.x, pl.y, 1,1, pl.facing==-1)

end


-->8
function build_world()
 local l = 10
 local ldy = 1
 local ls = l
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
	 	printh(i \ hwr..","..l/hhr)
	 	sw[i \ hwr] = l/hhr
	 end
	 
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
