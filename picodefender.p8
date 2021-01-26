pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
debug = true

ww = 128 * 9
cx = 128 * 4
ocx = cx

inertia_py = 0.95
inertia_cx = 0.99


hc = 128/4
hudy=12  -- = hudh
hudw=hc*2
hwr = ww/hudw
hhr = (128-4 - hudy)/hudy + 1
lmin = 3
lmax = 56

max_speed = 4
thrust = 1
vert_accel = 0.6
max_vert_speed = max_speed/2

laser_expire = 1
laser_size = 40  -- see rate
laser_rate=8
laser_max_length = 50  -- cap
min_laser_speed = 0.1  -- e.g. static ship, move away still
laser_speed = 1.8
laser_inertia = 0.999

function _init()
	w = {}  -- ground + stars
	sw = {} -- ground summary
	stars = {}
	actors = {}

	cx = 128 * 4
 cdx = 0

	build_world()
	
	pl = {
		x=64,  -- todo add cx and remove elsewhere
		y=64,
		
		facing=1,
		dx=0,
		dy=0,
	}
	
	lasers = {}

	add_stars()
	
	add_enemies()
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
 

 if btnp(❎) then
  local x = pl.x
 	if pl.facing > 0 then
 		x = x+8 + 1+1+1
 	end
 	add(lasers, {cx+x - 2,pl.y+7,pl.facing,time(),max(cdx, min_laser_speed)})
 end
 local t=time()
 for laser in all(lasers) do
 	if t-laser[4] > laser_expire then
 		del(lasers,laser)
 	end
 	laser[1] += laser[5]*laser[3] * laser_speed
 	laser[5] *= laser_inertia
 end
 --if btnp(🅾️) then -- z
 	-- smart bomb
 --end
 
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
	--x=hc + ((ocx + wx)\hwr) % hudw
	x=hc + ((ocx + wx - cx)\hwr) % hudw
	y=wy\hhr
	return x,y
end

function wxtoc(wx)
	x=wx - cx
	return x
end


function draw_hud()
 local hdc = hudw/9
 
 -- ground
	for x = 0,hudw-1 do
		i = (x + (ocx + 128 + cx)\hwr) % hudw + 1
		pset(hc+x,hudy - (sw[i]), 4)
	end
	
	-- player
 local	sx,sy = wtos(cx+pl.x, pl.y)
	pset(sx,sy, 8)

	-- enemies
	for enemy in all(actors) do
		sx,sy = wtos(enemy.x, enemy.y)
		pset(sx,sy, 11)
	end

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

function draw_player()
	local t=time()
	for laser in all(lasers) do
		--printh(tostr(laser))
		local x,y = wxtoc(laser[1]), laser[2]
		local age = (t-laser[4]) / laser_expire
		local mdx,mdy=1/8,0
		tline(x,y,
				  	x+min(((age * laser_size)* laser_rate * laser[3]), laser_max_length), y, 
				  	0,0,
				  	mdx,mdy
		)
	end
	
	spr(2, pl.x, pl.y, 1,1, pl.facing==-1)
end

function draw_enemies()
	local t=time()
	for enemy in all(actors) do
		local x,y = wxtoc(enemy.x), enemy.y
		--printh(x)
		spr(9, x, y, 1,1)
	 -- todo animate?
	end
end

function draw_stars()
--	for x = 0,127 do
--  i = ((ceil(cx+x))%ww) + 1
--		printh(i..","..#w[i])
--		if #w[i]>1 then
--			printh(i..","..w[i][2][2].." "..cx+x)
--			printh(x+w[i][2][2])
--			pset(
--				--ceil(cx+x)-(cx/w[i][2][2]),
--				--x - (cx/w[i][2][2])*1/34,
--				--(cx+x - (cx/w[i][2][2])*1) -cx,
--				x + cx/w[i][2][2]*0.3,
--				w[i][2][1], 
--				10
--			)
--		end
--	end

	--local dist = cx/ww
	for star in all(stars) do
		--local x = ((star[1] - cx)\hwr + star[3]*(3/10))
		--local x = star[1] - (cx/star[3])
		--local x = ((cx+star[1])%ww) + (star[3]*(3/10))
		--local x = star[1] - (cx/star[3])
		local x = star[1] - (cx/star[3])  -- -cx for screen; /star[3] for move-delay
		local col = 6
		if cx + 128 > ww then
			--if star[1] < (128 - (ww-cx)) then
			--printh("?"..star[1]-(cx/star[3]).." < "..(128 - (ww-cx)))
			--if false then --!!!  star[1]-(cx/star[3]) < (128 - (ww-cx)) then
			if star[1]-(cx/star[3]) < (128 - (ww-cx)) then
				--x = (star[1] + ww) - (cx/star[3])
				--x = (star[1] + ww) - (cx/star[3])
 			x = (star[1]+(ww/star[3])) - (cx/star[3])
				col = 14  --new or fade depending on dir
				printh(cx.." wrap "..star[1].." "..x)
			end

			--if star[1]-(cx/star[3]) > (ww-128) then
			if star[1] > ((ww/star[3]) - 128) then
			--if star[1] > ((ww) - 128) then
				--x = (star[1] + ww) - (cx/star[3])
				--x = (star[1] + ww) - (cx/star[3])
 			--x = (star[1]+(ww/star[3])) - (cx/star[3])
 			if col == 14 then
 				--all! how!? 
 				--col = 11  --new+fade?
 			else
					col = 12  --fade or new depending on dir
				end
				printh(cx.." fade "..star[1].." "..x)
			end
		end
--		if cx < 0 then
--			if star[1] > (ww - (128-cx)) then
--				x = (star[1] - ww) - (cx/star[3])
--				printh(cx.." wrap "..star[1].." "..x)
--			end
--		end
		--printh(star[1].." -"..(cx/star[3]).." -> "..x)
		--printh(col)
		
		if (col ~= 6) col = 5
		
		pset(x, star[2], col)
	end
end

function _draw()
 cls()

	draw_stars()

	draw_hud()

	-- draw_ground	
	for x = 0,127 do
		i = ((ceil(cx+x))%ww) + 1
		--printh(i)
		pset(x,127 - w[i][1], 4)
	end

	draw_enemies()

	draw_player()

		
	if debug then
		print(cx,1,1)
		print(cdx,1,7)
		if cx + 128 > ww then
			print("★",1,14)
		end
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

	 -- todo make level ends meet!	 
	 
	 --if rnd() < 0.05 then
		--w[i] = {l, {rnd(127-hudy-lmax-8)+hudy, rnd(2)+10}}
	 --else
		w[i] = {l}
		--end
	end
end

function add_stars()
	for s = 1,100 do
		add(stars, {rnd(ww), rnd(127-hudy-lmax-8)+hudy, rnd(2)+10})
	end
end

function add_enemies()
 add(actors, {
  x=600,
  y=64,
 })
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000009900000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000b99b0000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000bb0b0b000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000bb0b0b009990000000000000000000000000000000000000000000000000000
000770000000000006600000000000000000000000000000000000000000000000b9b900b0b0b000000000000000000000000000000000000000000000000000
007007000d000000e6660000000000000000000000000000000000000000000000b0bb00b9b9b000000000000000000000000000000000000000000000000000
00000000dddd19006e66661000000000000000000000000000000000000000000b00b0b00bbb0000000000000000000000000000000000000000000000000000
000000000e73dd73eee6666b0000000000000000000000000000000000000000b000b00bb0b0b000000000000000000000000000000000000000000000000000
70707007770700770077070707077077707770707077777077777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1011121314151617000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
