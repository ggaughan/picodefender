pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
-- pico defender
-- ggaughan, 2021
-- remake of the williams classic

version = 1.00

cart0=0  -- 32 bits: 0=epi_friendly

t=time()

today,alltime=1,2
e_hs={nil,0}
highscores={
	{e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs},
	{e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs,e_hs},
}
init_hs="drj=13293.75,sam=11446.875,led=9950,pgd=8928.125,gjg=8256.25" -- >>12

ww,cx=1152,512  
ocx=cx

hc=32
hudy,hudw=12,hc*2
hwr=ww/hudw
hhr=(124-hudy)/hudy+1
lmax=82

human=7
lander=9
mutant=25
bomber=57
pod=73
swarmer=89 
baiter=41  
mine=105 
bullet=24	

demo_sx,demo_sy=108,(128-hudy)/2
demo_ty=14
demo={
	t=0, 
	step=0,
	step_next_part=1,
	steps={
		lander,
		mutant,
		baiter,
		bomber,
		pod,
		swarmer
	}
}
ns="lander,mutant,baiter,bomber,pod,swarmer"
names=split(ns)
attrs={
	-- points,colour,w,h,frames,attack-prob,speed,attack sfx
	[lander]={100,11,5,7,3,0.0025,0.15,7},
	[mutant]={150,5,5,7,3,0.006,0.5,13},
	[baiter]={200,11,4,7,3,0.015,2.2,15},
	[bomber]={250,14,4,4,3,0.005,0.3,nil},
	[pod]={1000,8,5,7,4,1.00,0.2,nil},
	[swarmer]={150,9,4,5,1,0.004,0.7,14},
	
	[human]={500,6,6,3,2,1.00,0.02,nil},
	
	[bullet]={0,6,1,1,1,1.00,1.0,nil},
}


max_stars=100

wave_colours={1,3,8,9,10,4,0}
waves={
 {
		landers=15,
		bombers=0,
		pods=0,
	},
 {
		landers=20,
		bombers=3,
		pods=1,
	},
 {
		landers=20,
		bombers=4,
		pods=3,
	},
 {
		landers=20,
		bombers=5,
		pods=4,
	},
}

inertia_py=0.90
inertia_cx=0.97

max_speed,thrust=2,0.4
vert_accel=0.6
max_vert_speed=max_speed/2
max_h_speed_factor=max_speed/48

laser_expire=0.5
laser_size,laser_rate=22,4
laser_max_length,laser_min_length=70,1
min_laser_speed=0.2 
laser_speed=1.8
laser_inertia=0.999

lander_speed=attrs[lander][7]  
lander_speed_y_factor=2
bullet_expire=1.4  
mine_expire=6

particle_expire=0.8
particle_speed=0.6

player_birth_expire=1
player_exp_delay=0.4
player_die_expire=3
old_particle=1
enemy_die_expire=1

max_humans=10
target_x_epsilon=3
target_y_epsilon=4
capture_targetted=1
capture_lifted=2
gravity_speed=0.16
safe_height=80

wave_progression=15  
wave_old=60  
baiter_next=wave_progression/3  
max_baiters=4
max_swarmers=20
wave_reset=2  
delay_first_enemies=0.5 

extra_score_expire=1
bombing_expire=0.3 
ground_destroy_expire=2

title_delay=8
title_particle_expire=1.4
game_over_delay=4
new_highscore_delay=60 
hs_chr="a"

function toggle_bit1()
	epi_friendly,cc=not epi_friendly,10
	cart0^^=0b0001
	dset(0, cart0)
end

function _init()
	cart_exists=cartdata("ggaughan_picodefender_1")
	if (cart_exists)	cart0=dget(0)
	epi_friendly=cart0&0b0001!=0

	menuitem(1,"toggle flashing",toggle_bit1)

	poke(0x5f5c,255) 

	w={}  
	sw={} 
	stars={}
	cx=512  
 cdx=0
 canim,canim_dx=0,0

	build_world() 
	add_stars()
	
	load_highscores()
	
	pl={
		w=6,
		h=3,
		x=0,y=0,

	 c=7,  
	 
	 thrusting_t=0,
	 thrusting_spr=0,
	 hit=nil,  
	}

	actors={}
	particles={}
	
	reset_player(true) 
	lasers={}
	iwave=0
	humans=0  
	add_humans_needed=true
 load_wave() 
	
	pt=t 
	cc=10
	
	extra_score=nil
	bombing_t=t  
	bombing_e=bombing_expire*3 

	old_p=nil	
 pl.hit=t 
	_draw=_draw_title
	_update60=_update60_title
end

-->8
--update

function _update60_wave()
 t=time()
 update_particles()  
	if pl.hit==nil and pl.birth==nil then
	 if btnp(⬅️) then
		 pl.facing*=-1
		 canim=80
		 canim_cdx=cdx
		 canim_dx=pl.facing
	  cdx*=0.5
	  if (btn(➡️)) canim_cdx*=1.5
		end
	 if (btn(➡️)) cdx=min(cdx+thrust,max_speed)
	 if btn(⬆️) then
	  pl.dy-=vert_accel
	  if (pl.dy<-max_vert_speed) pl.dy=-max_vert_speed
	 end
	 if btn(⬇️) then
	  pl.dy+=vert_accel
	  if (pl.dy>max_vert_speed) pl.dy=max_vert_speed
	 end
	 for laser in all(lasers) do
	 	laser[1]=(laser[1] + laser[5]*laser[3] * laser_speed)%ww
	 	laser[5]*=laser_inertia
	 	if (t-laser[4]>laser_expire) del(lasers,laser)
	 end

	 if btnp(❎) then
	  local x=pl.x
	 	if (pl.facing>0)	x+=9
	 	add(lasers, {x-2,pl.y+5,pl.facing,t,max(cdx, min_laser_speed)})
	 	sfx(48,3)
	 end
	 
	 if btnp(🅾️) then 
	 	if btn(⬆️) and btn(⬇️) then
	 		pl.birth=t
	 		local hx=rnd(ww)
	 		cx+=hx
	 		pl.x+=hx
	 		if (rnd()<0.5) pl.facing*=-1
	 		cdx=0
			 canim,canim_dx=80,pl.facing
				add_explosion(pl, true)
	 	else 
		 	if pl.bombs>0 then
			 	sfx(6)
			 	bombing_t,bombing_c=t,7
			 	bombing_e=bombing_expire
					for e in all(actors) do
				  if not(e.k==human) then
							local sx=wxtoc(e.x)
							if sx>=0 and sx<=127 then
								e.hit=t
							 kill_actor(e, nil)
							end
				  end
					end	
		 		pl.bombs-=1
			 end
			end
	 end
	 
	 pl.dy*=inertia_py
	 pl.y+=pl.dy 
	 
	 cdx*=inertia_cx
	 cx=(cx+cdx*pl.facing)%ww
	 pl.x+=cdx*pl.facing  
	 if canim>0 then
			pl.x+=canim_cdx*-pl.facing	 
	 	canim_cdx*=inertia_cx
	 end
	
		local x=wxtoc(pl.x)
	 if pl.facing==1 then
	 	if (x<40 and btn(➡️)) pl.x+=cdx * max_h_speed_factor
	 	if (x>20 and not btn(➡️)) pl.x-=thrust/2  
	 else
	 	if (x>80 and btn(➡️)) pl.x-=cdx * max_h_speed_factor
	 	if (x<100 and not btn(➡️)) pl.x+=thrust/2  
	 end
	 
		if btn(➡️) then
			pl.thrusting=true
		 sfx(3)
		else 
	 	pl.thrusting=false
			sfx(3, -2)
		end
	 if t-pl.thrusting_t>0.05 then
			pl.thrusting_spr=(pl.thrusting_spr+1)%4
			pl.thrusting_t=t
		end

	 pl.x=pl.x%ww
	 
	 if pl.y<hudy then
	 	pl.y, pl.dy=hudy,0
	 elseif pl.y>120 then
	  pl.y,pl.dy=120,0
	 end

	 update_enemies()  

	 for plt in all(pl.target) do
		 if plt.capture==capture_lifted then
		 	plt.x=pl.x 
		 	plt.y=pl.y+6 

				if plt.y>116 then
 		 	plt.x+=rnd(8)-4
 		 	plt.y+=rnd(4)+1
			 	plt.dy=gravity_speed
			 	plt.dropped_y=pl.y
					sfx(19)
					add_pl_score(plt.score, plt.x-12, plt.y+2)	
					plt.capture=nil
			 	del(pl.target,plt)
			 end
			end
	 end
	 
	 update_wave()
	end
end

function update_enemy(e,target,ymargin)
	local chasex,dyfactor=true,1
	local flipx,flipy,closex,closey=0,0,0,24
	if (e.k==baiter) flipy,closex,closey,dyfactor=0.1,24+rnd(12),24+rnd(16),3
	if (e.k==swarmer) chasex,flipx,flipy,closey=false,0.05,0.1,80
 local ytb,rand=rnd(ymargin),rnd()
	local dx=abs(e.x-target.x)
	if dx>closex then
		if dx<rnd(256)-e.lazy then
		 local s=attrs[e.k][7]
		 if (iwave>6) s+=0.10
			if chasex or e.dx==0 then
			 if e.x<target.x or rand<flipx then
				 e.dx=s
				else
				 e.dx=-s
			 end
			end
		end
	else
	 e.dx*=0.96+rnd(0.08)  
	 if (rand<0.2) e.dx=sgn(e.x-pl.x)
	 if (rnd()<0.02) e.dx*=-1  
	end
	
	local dy=abs(e.y-target.y)
	if dy>closey then
		if (e.dy==0) e.dy=-lander_speed
	 if (
	 				(e.y<hudy+ytb and e.y<target.y and e.dy<0) 
	 				or
	 				(e.y>120-ytb and e.y>target.y and e.dy>0)
	 ) then
	 	e.dy*=-1*dyfactor
	 end
	else
		e.dy=0
	 if (rand<flipy) e.dy=-sgn(e.y-target.y)
	 if (rnd()<0.02) e.dy*=-1
	end

	enemy_attack(e)
end

function update_enemies()
	for e in all(actors) do
	 local laserable=e.k~=mine
	 if laserable and e.k==human and e.capture==capture_lifted then
		 for plt in all(pl.target) do
		 	if (plt==e) laserable=false
			end
	 end
 	if laserable then
		 for laser in all(lasers) do 	
		  if not e.hit then
					local age=(t-laser[4])/laser_expire
					local x,y=laser[1],laser[2]			
					local tl=age*laser_size*laser_rate
					local tx=x+(laser[3]*tl) 
					if (laser[3]>0 and side(x,e.x,laser[3]) and tx>(e.x+e.xl+e.dx) 
					   or 
					   laser[3]<0 and side(x,e.x,laser[3]) and tx<(e.x+e.xr+e.dx)) then
						if y>=e.y+e.dy+e.yt and y<=e.y+e.dy+e.yb then
							if t-laser[4]>0.0167 then -- or abs(pl.x-e.x)<13 then
					 		e.hit=t
							 kill_actor(e, laser)
							end
						end
					end
			 end		
			end
		end
		
		if not e.hit then  
			local x=(e.x+4+e.dx)-(pl.x+4)
			local y=(e.y+4+e.dy)-(pl.y+4)  
			if e.k~=human then
				if abs(x)*2<(e.w+pl.w) and
						 abs(y)*2<(e.h+pl.h)
				then
				 if (e~=bullet or e.t-t>0.0167) then
	  			e.hit=t
				 	kill_player(e)
				 end
				end
			else 
				if e.capture==nil and e.y<116 and abs(e.x-pl.x)<target_x_epsilon*2 and abs((e.y-4)-pl.y)<target_y_epsilon*2 then
					e.capture=capture_lifted
			 	add(pl.target,e)
			 	e.dy,e.dx=0,0 
					if demo.t==0 then
					 sfx(18)
						add_pl_score(e.score, pl.x-12, pl.y+4)
					end
				end
			end			
			
			if not e.hit then
				e.x=(e.x+e.dx)%ww
		  e.y+=e.dy
			
				if demo.t==0 then	
					if e.k==lander then  
						if e.target~=nil then
						 if e.target.capture==capture_lifted then
						 	e.target.x=e.x 
						 	e.target.y=e.y + 7
						 	if e.y<=hudy then
						 		kill_actor(e.target,nil,false)  
						 		e.k=mutant
 					 		e.c=attrs[mutant][2]
						 		e.lazy=0  
									e.dy=attrs[mutant][7] 
						 	end
						 elseif e.target.capture==capture_targetted and abs(e.x-e.target.x)<target_x_epsilon and abs(e.y-e.target.y)<target_y_epsilon then
						 	e.dy=-lander_speed*(lander_speed_y_factor/2)
						 	e.dx=0  
								e.target.capture=capture_lifted
								e.target.dy=gravity_speed  
								e.target.dx=0
								sfx(10)
						 elseif e.x<e.target.x then
							 e.dx=lander_speed
			 				if (e.y<hudy+90 and e.dy<0) e.dy*=-1
							else
							 e.dx=-lander_speed
			 				if (e.y<hudy+90 and e.dy<0) e.dy*=-1
						 end			
	 				else
							if rnd()<0.15 then
								e.dx=lander_speed*(0.9+rnd())
								if (rnd()<0.1) e.dx*=-1
							--elseif rnd()<0.05 then
							--	e.dx=0
							end
							if (rnd()<0.01 and e.y<100) e.dy=lander_speed
							--	e.dy=lander_speed*lander_speed_y_factor*(0.5+rnd())
							--end
						end									
						enemy_attack(e)
					elseif e.k==mutant then
						update_enemy(e,pl,20)
					elseif e.k==baiter then
						update_enemy(e,pl,30)
					elseif e.k==bomber then
					 if (e.y<hudy+rnd(30) or e.y>120-rnd(30)) e.dy*=-1
					 enemy_attack(e)
					elseif e.k == swarmer then
						update_enemy(e,pl,40)
					elseif e.k==mine then
				 	if (t-e.t>mine_expire) del(actors,e)
					elseif e.k==bullet then
				 	if (t-e.t>bullet_expire) del(actors,e)
				 elseif e.k==human then
						if e.dropped_y~=nil then
						 if e.y>119 then
								e.y,e.dy=120,0
								if e.dropped_y<safe_height then
						 		kill_actor(e,nil,true)  
								else
								 if (e.dropped_y<=110)	add_pl_score(250)
								end
								e.dropped_y=nil
							end
						end 	 
					end
						
					if e.y<=hudy then
						e.y=hudy+1
						e.dy*=-1
					 if (e.k==bullet) del(actors,e)
					elseif e.y>120 then
						e.y=120 
						e.dy*=-1
					 if (e.k==bullet) del(actors,e)
					end 			
				else
					if e.y<hudy+demo_ty then
 					e.y,e.dy=hudy+demo_ty,0 
						demo.step_next_part+=1
					end			
					if e.k==lander then  
						if e.target~=nil then
						 if e.target.capture==capture_lifted then
						 	e.target.x=e.x 
						 	e.target.y=e.y + 7
						 elseif e.target.capture==capture_targetted and abs(e.x-e.target.x)<target_x_epsilon and abs(e.y-e.target.y)<target_y_epsilon then
						 	e.dy=-lander_speed*3.1
								e.target.capture=capture_lifted
								e.target.dy=gravity_speed*3  
							end
						end
					end
				end			
			end
		end
	end
end

function update_particles()
	for e in all(particles) do
 	if t-e.t>e.expire then
 		del(particles,e)
 	else
			if (t-e.t>old_particle) then
			 e.dx*=0.99
			 e.dy*=0.99
			end	
			if t>e.t then
		  e.y+=e.dy  
		  if e.y<=hudy or e.y>127 then
		 		del(particles,e)
		  else
			  e.x=(e.x+e.dx)%ww
				end
			end
	 end
	end
end

function update_wave()
	if t-wave.t_chunk>wave_progression then
  wave.t_chunk=t  
		if	add_humans_needed then
			add_humans()
	 end
		if (wave.landers>0 or wave.mutants>0 or wave.swarmers_loosed>0 or t-wave.t>wave_old)	add_enemies()
	end
end

function _update60_game_over()
	t=time()
	local age=t-pl.hit
	local timeout=age>game_over_delay
	local some_timeout=age>2  

 update_particles()  
 
 if pl.score>highscores[today][8][2] then
  if timeout then
			actors={}  
			particles={}
			lasers={}
	
	 	hs_name,hs_chr="","a"
	  pl.hit=t
	 	_update60=_update60_new_highscore
	 	_draw=_draw_new_highscore
	 end
 else
	 if timeout or (some_timeout and btnp(➡️)) then
			actors={}  
			particles={}
			lasers={}
	
	  pl.hit=t
	 	_update60=_update60_highscores
	 	_draw=_draw_highscores
	 elseif some_timeout and (btnp(🅾️) or btnp(❎)) then
	  start_game(true)
	  
	  pl.hit=t
	 	_update60=_update60_wave
	 	_draw=_draw_wave
	 end
	end
end

function _update60_title()
	t=time()
	local timeout=(t-pl.hit)>title_delay
	
 update_particles()  
 
 if timeout or btnp(➡️) then
	 pal(10, 10)  
  bombing_t=t  
  particles={}
  pl.hit=t  
 	_update60=_update60_highscores
 	_draw=_draw_highscores
	elseif btnp(🅾️) or btnp(❎) then
	 pal(10, 10)  
  start_game(true)
  pl.hit=nil  
 	_update60=_update60_wave
 	_draw=_draw_wave
 end
end

function _update60_highscores()
	t=time()
	local timeout=(t-pl.hit)>title_delay

 update_particles()  
 
 if timeout or btnp(➡️) then
  pl.hit=t

		demo.step=0
		demo.step_next_part=1
		demo.t=t 
		cx=ocx
		h=make_actor(human,cx+demo_sx,116,t) 
		h.capture=nil
		h.dropped_y=nil
		h.capture=capture_targetted

		pl.facing=1
		pl.lives,pl.bombs=0,0
		pl.x,pl.y=cx+8,hudy+12

 	_update60=_update60_instructions
 	_draw=_draw_instructions
	elseif btnp(🅾️) or btnp(❎) then
  start_game(true)
  pl.hit=nil  
 	_update60=_update60_wave
 	_draw=_draw_wave
 end
end

function _update60_new_highscore()
	t=time()

 update_particles()  

	if btnp(⬆️) then  
		hs_chr=ord(hs_chr)+1
		if (hs_chr==123) hs_chr=32
		if (hs_chr==33) hs_chr=97
		hs_chr=chr(hs_chr)
		pl.hit=t  
	elseif btnp(⬇️) then  
		hs_chr=ord(hs_chr)-1
		if (hs_chr==96) hs_chr=32
		if (hs_chr==31) hs_chr=122
		hs_chr=chr(hs_chr)
		pl.hit=t  
	elseif btnp(❎) then
		hs_name=hs_name..hs_chr
		pl.hit=t  
		if #hs_name>=3 then
			add_highscore(pl.score, hs_name)
	  pl.hit=t 
	 	_update60=_update60_highscores
	 	_draw=_draw_highscores
		end
	elseif btnp(🅾️) then
		if #hs_name>0 then
			hs_chr=sub(hs_name, #hs_name, #hs_name)
		 hs_name=sub(hs_name, 1, #hs_name-1)
		end
		pl.hit=t  
 end

 if (t-pl.hit)>new_highscore_delay then
		add_highscore(pl.score, hs_name)
  pl.hit=t
 	_update60=_update60_highscores
 	_draw=_draw_highscores
 end
end

function _update60_instructions()
	t=time()
	local timeout=t-pl.hit>title_delay

	if demo then
		local l
	 if demo.step<=#demo.steps then
	  timeout=false  
	  if demo.step==0 then
				if demo.step_next_part==1 then
					l=make_actor(lander,cx+demo_sx,hudy+demo_ty+16,t)
					l.target=h
					l.dy=lander_speed*4
					add_explosion(l,true)
					demo.step_next_part+=1
				elseif demo.step_next_part==3 then
			 	add(lasers, {pl.x+9,pl.y+5,pl.facing,t,max(max_speed/2, min_laser_speed)})  
					demo.step_next_part+=1
				elseif demo.step_next_part==5 then
			 	h.capture=nil
					if (t-bombing_t>particle_expire) demo.step_next_part+=1
				elseif demo.step_next_part==6 then
					if (t-bombing_t>particle_expire) demo.step_next_part+=1
				elseif demo.step_next_part==7 then
					pl.x+=1.2
					pl.y+=0.8				
					if (pl.x>=cx+demo_sx) demo.step_next_part+=1
				elseif demo.step_next_part==8 then
					pl.y+=0.5				
			 	h.y=pl.y+6 
					if h.y>116 then
					 extra_score={h.score>>16, wxtoc(h.x-8),h.y+4, t}
						demo.step_next_part+=1
					end
				elseif demo.step_next_part==9 then
					pl.facing=-1
					pl.x-=0.95
					pl.y-=0.81
					if pl.y<hudy+13 then
						pl.facing=1
						demo.step_next_part+=1
					end
				end
				if demo.step_next_part==10 then
					demo.step+=1 
					demo.step_next_part=1
				end 	
	  else
				if demo.step_next_part==1 then
					l=make_actor(demo.steps[demo.step],cx+demo_sx,demo_sy,t)
					l.dy=-lander_speed*3
					add_explosion(l,true)  
					demo.step_next_part+=1
				elseif demo.step_next_part==3 then
			 	add(lasers, {pl.x+9,pl.y+5,pl.facing,t,max(max_speed/2, min_laser_speed)})	 
					demo.step_next_part+=1
				elseif demo.step_next_part==5 then
					if (t-bombing_t>particle_expire) demo.step_next_part+=1
				elseif demo.step_next_part==6 then
					l=make_actor(demo.steps[demo.step],cx+12+((demo.step-1)%3*36),demo_sy-20+((demo.step-1)\3)*30,t)
					l.name=names[demo.step]
					add_explosion(l, true)  
					bombing_t=t
					demo.step_next_part+=1
				elseif demo.step_next_part==7 then
					if (t-bombing_t>particle_expire*1.2) demo.step_next_part+=1
				end
				if demo.step_next_part>7 then
					demo.step+=1
					demo.step_next_part=1
				end
			end
		else
		 if demo.step==#demo.steps+1 then
				pl.hit=t  
				demo.step+=1
				timeout=false
			end
		end

		for laser in all(lasers) do
	 	laser[1]=(laser[1] + laser[5]*laser[3] * laser_speed)%ww
	 end

	end	

 update_particles()  
 update_enemies()  

 if timeout or btnp(➡️) then
  actors={}
  particles={}
  demo.t=0 
  pl.hit=t  
		bombing_t=t
		bombing_e=bombing_expire*3 
 	_update60=_update60_title
 	_draw=_draw_title
	elseif btnp(🅾️) or btnp(❎) then
  actors={}
  demo.t=0 
  start_game(true)
  pl.hit=nil  
 	_update60=_update60_wave
 	_draw=_draw_wave
 end
end

function start_game(full)
 if full then 
 	music(23,0,15)  
		reset_player(true)
		actors={}  
		lasers={}
		iwave=0  
		humans=0  
		add_humans_needed=true
		load_wave()
	end
 bombing_t=nil
 bombing_e=bombing_expire
 particles={}
 add_humans()  
 add_enemies(t+delay_first_enemies)
end

-->8
--draw

function wtos(wx,wy)
	return hc+((ocx+wx-cx)\hwr)%hudw,wy\hhr
end

function wxtoc(wx)
	if (cx+128>ww and wx<(128-(ww-cx))) return (wx+ww)-cx
	return wx-cx
end

function side(l,e,cmp)
 if (e<128 and l>ww-128 and cmp==1) return true
 if (l<128 and e>ww-128 and cmp==-1) return true
	if (e>=l and cmp==1) return true
	if (e<=l and cmp==-1) return true
	return false
end

function draw_ground(force_ground)
	if force_ground or humans>0 then
		for x=0,127 do
			local i=((ceil(cx+x))%ww)+1
			pset(x,w[i], 4)
		end
	end
end

function draw_score(v, x,y, extra)
 x=x or 0
 y=y or 6
 local c,i=5,6
 repeat
  local t=v>>>1
  if (extra and i==4) c=10 
  print((t%0x0.0005<<17)+(v<<16&1),x+i*4,y,c)
  v=t/5
 	i-=1
 until v==0
end

function add_pl_score(v, x, y)
 if (x and y) extra_score={v>>16, wxtoc(x),y, t}
	pl.score+=v>>16
	pl.score_10k+=v>>16
	if pl.score_10k>=10000>>16 then
		pl.lives=min(pl.lives+1,255)
		pl.bombs=min(pl.bombs+1,255)
		pl.score_10k-=10000>>16
	end
end

function draw_hud(force_ground)
 local hdc=hudw/9
 
	if force_ground or humans>0 then
		for x=0,hudw-1 do
			local i=(x+(ocx+128+cx)\hwr)%hudw+1
			pset(hc+x,sw[i],4)
		end
	end
	
	for e in all(actors) do
	 if e.k~=bullet and e.k~=mine then
			sx,sy=wtos(e.x,e.y)
			pset(sx,sy,e.c)
		end
	end

 local	sx,sy=wtos(pl.x,pl.y)
	pset(sx,sy,7)

	local c=1
	if (wave) c=wave.c
	local sl,sr=hc+hdc*4-1,hc+hdc*5+1
	rect(hc,0,hc+hudw,hudy, c)
	line(0,hudy,127,hudy, c)
	line(sl,0,sr,0, 7)
	pset(sl,1, 7)
	pset(sr,1, 7)
	line(sl,hudy,sr,hudy, 7)
	pset(sl,hudy-1, 7)
 pset(sr,hudy-1, 7)
 
 draw_score(pl.score)
 if extra_score then
 	if t-extra_score[4]<extra_score_expire then
		 draw_score(extra_score[1], extra_score[2],extra_score[3], true)
		else
		 extra_score=nil
		end 
 end
 
 for i=1,min(pl.bombs,3) do
 	spr(4,25,-7+i*4)
 end
 for i=1,min(pl.lives,5) do
 	spr(5,(i-1)*5,-4)
 end
end

function draw_player()
	for laser in all(lasers) do
		local x,y=wxtoc(laser[1]), laser[2]
		local age=(t-laser[4])/laser_expire
		local mdx,mdy=1/8,0
		tline(
		 x,
			y,
			x+min(
			  		max((age * laser_size) * laser_rate, 
    	  				laser_min_length
				  		  ) 
 		  		, 
	 			 	laser_max_length 
		 		 ) * laser[3], 
  	y, 
	 	0,0,
	 	mdx,mdy
		)
	end
	
	if pl.hit~=nil and demo.t==0 then
		local age=t-pl.hit
		if (age<=player_exp_delay and old_p)	spr(2+(age*100)%2, wxtoc(old_p[1]), old_p[2], 1,1, old_p[3]==-1)
		if age>player_die_expire then
			pl.hit=nil	
 		reset_enemies()  
		end
	elseif pl.birth~=nil then
		if (t-pl.birth>player_birth_expire) pl.birth=nil	
	else
		local x=wxtoc(pl.x)
		spr(2, x, pl.y, 1,1, pl.facing==-1)
		spr(32+(pl.thrusting and 0 or 16)+pl.thrusting_spr, x-(8*pl.facing), pl.y, 1,1, pl.facing==-1)
	end
end

function draw_enemies()
	for e in all(actors) do
		if e.hit~=nil then
			if (t-e.hit>enemy_die_expire)	e.hit=nil
		else
			local x,y=wxtoc(e.x),e.y
			local fx=(e.k==human and e.dx>0)
 		spr(e.k+e.frame,x,y, 1,1, fx)
			if not(e.k==bullet or e.k==mine) then
	 		e.t+=1
	 		if e.t%12==0 then
	 		 if (e.k~=human or (e.t%48==0 and abs(e.dx)>0)) e.frame=(e.frame+1)%e.frames
	 		end
	 		if demo.t~=0 and e.dy==0 and y~=hudy+demo_ty and e.k~=human then
					print(e.name,x-((#e.name/2)*3)+4,y+10, 5)		
					print(e.score,x-(((#tostr(e.score)+1)/2)*3)+6,y+17, 5)		
	 		end
			end
		end
	end
end

function draw_particles(alt_cycle)
	local occ,cc_freq = 5,0.2
	if (alt_cycle) occ,cc_freq = 10,0.05
 if t-pt>cc_freq then
  if not epi_friendly then
	  cc=(cc%15)+1
		end
	 pal(occ,cc) 
	 pt=t
 end
 
	for e in all(particles) do
		if t>e.t then
			local x,y=wxtoc(e.x),e.y
			local c=e.c
			if (t-e.t>old_particle) c=9
			pset(x,y,c)	
		end
	end
end

function draw_stars()
	for star in all(stars) do
	 if not(humans<=0) and star[2]>lmax then
	 else
 	 local cxp=cx/star[3] 
			local x=star[1]-cxp  
			local col=5
			if cx+128>ww then
				if star[1]-cxp<(128-(ww-cx)) then
	 			x=(star[1]+(ww/star[3]))-cxp
					col=14 
				end
				if star[1]>((ww/star[3])-128) then
	 			if (col~=14) col=12  
	 		end
			end
			if (col~=5) col=5
			pset(x,star[2],col)
		end
	end
end

function animate_camera()
	canim-=1
	cx=(cx+canim_dx)%ww
	local x=wxtoc(pl.x)
	if x<20 then
 	pl.x=(cx+20)%ww
 	canim=0
	elseif x>100 then  
	 pl.x=(cx+100)%ww
	 canim=0
	end
end

function _draw_game_over()
 cls()
	draw_stars()
	draw_hud()
	draw_ground()
	draw_enemies()
	draw_particles()
	
	local age=t-pl.hit
 if (age<=player_exp_delay)	spr(2+(age*100)%2, wxtoc(old_p[1]), old_p[2], 1,1, old_p[3]==-1)
	if (age>1) print("game over", 48, hudy+40, 5)
end

function _draw_title()
 cls()
	draw_particles(true)
	if bombing_t==nil or t-bombing_t>bombing_e then
		map(0,1, 25,hudy+1, 10,4)
		print("by", 59, hudy+40, 7)
		print("greg gaughan", 39, hudy+46, 7)
	else
		for i=1,32 do
		 if i~=16 then
				local o=(i-16)*easeinoutquad(1-(t-bombing_t)/bombing_e)*2
				tline(25,hudy+1+i+o,25+80,hudy+1+i+o, 0,i/8+1, 1/8,0)
			end
		end
	end
	local o=hudy+78
	print("⬆️ UP  ⬇️ DOWN", 36, o, 15)
	print("❎ FIRE ➡️ THRUST", 30, o+6, 15)	
	print("⬅️ REVERSE 🅾️ BOMB", 28, o+16, 1)	
	print("⬆️⬇️🅾️ HYPERSPACE", 30, o+22, 1)
	print("press ❎ to start", 30, o+32, 10)
end

function _draw_highscores()
 cls()
	if (pl.score>0) draw_score(pl.score)
	draw_particles()
	map(0,1, 25,0, 10,4)
	print("hall of fame", 41, hudy+23, 5)
	print("todays", 14, hudy+32, 5)
	print("all time", 86, hudy+32, 5)
	print("greatest", 10, hudy+38, 5)
	print("greatest", 86, hudy+38, 5)
 line(10, hudy+44, 40, hudy+44, 5)
 line(86, hudy+44, 116, hudy+44, 5)
	for hst=today,alltime do
	 local co=(hst-1)*76
		for i,hs in pairs(highscores[hst]) do
			local y=hudy+42+i*6
 		print(i, 1+co, y, 5)
		 if hs[1]~=nil then
				print(hs[1],10+co,y,5)
				draw_score(hs[2],24+co,y)
			end
		end
	end
end

function _draw_new_highscore()
 cls()
	draw_score(pl.score)
	draw_particles()
	print("player one", 48, hudy+1, 2)
	print("you have qualified for", 16, hudy+16, 2)
	print("the defender hall of fame", 16, hudy+24, 2)
	print("select initials with ⬆️/⬇️", 16, hudy+36, 2)
	print("press fire to enter initial", 16, hudy+48, 2)
	for ci=1,#hs_name do
 	print(sub(hs_name,ci,ci), 48+ci*10, 80, 2)
 end
 local ci=#hs_name+1
	print(hs_chr, 48+ci*10, 80, 2)
	for ci = #hs_name+1,3 do
	 local c=2
	 if (ci==#hs_name+1 and flr(t)%2==0) c=0
 	line(48+ci*10, 88, 48+ci*10+3, 88, c)
 end
end

function _draw_instructions()
 cls()
	draw_hud(true)  
	draw_ground(true)
	draw_enemies()
	draw_particles()
	draw_player()  
	print("scanner", 51, hudy+4, 5)
end

function _draw_end_wave()
 cls()
	draw_hud()
	draw_player() 
	rectfill(0, hudy+1,127,127, 0)
	print("attack wave "..(iwave+1), 40, hudy+20, 5)
	print("completed", 46, hudy+28, 5)
	print("bonus x "..100*min(iwave+1,5), 43, hudy+48, 5)
	for h=1,humans do
		spr(human,33+h*5, hudy+56)
	end
	if pl.hit==nil then
		reset_player()
		iwave=(iwave+1)%256
		load_wave()
		wave.t_chunk=t-wave_progression+wave_reset  
		_draw=_draw_wave
	end
end

function _draw_wave()
 if bombing_t~=nil then
		local age=t-bombing_t
		if age<bombing_e then
	  if not epi_friendly then
			 if flr(age*18)%2==0 then
					cls(bombing_c)
				else
					cls(0)
				end
			else
				cls()
			end
			local shake=4*easeinoutquad(age/bombing_e)
			camera(shake-rnd(shake), shake-rnd(shake))
		else
			camera(0,0)
			bombing_t=nil
			bombing_e=bombing_expire  
		end
	else
		cls()
	end
 if (canim>0) animate_camera()
	draw_stars()
	draw_hud()
	draw_ground()
	draw_enemies()
	draw_particles()
	draw_player()
end

-->8
--build world

function build_world()
	local wd=[[
	 5+3+2-2+2=4+2=2+2-2=4+2-2+3+2-2+3+2+4+7+2-2-2+3-2=3+4=2+3-7+7+2=
	 7-4-7-4=4-4-3-3+4-2+5-2+2=3-2+3+2-2+3-4=6=3-4=2-10=2-48=2+8=
	 3+36=2+10=4-14=3+2+2-3+2=2-6+3-2+2+4-2+3-3-6=2-2+2+2+2+4=2+4=3-4-2+3-3+4=6-2=4+4+4=4+5-2=4+3+2=4+2-4=2-2+4=2+5-2+8-
	 18=2+4=3-18=6=20+20-10=6+6-24=5+5-12=
	 7+7-6=20+20-6=9+7-12=4+4-10=
	 6-14+8-10=4+8-20+14-4+6-10=3-
	 20=4=2+10=2+4=4+12=6+6-4+4-6+2-6=8+20-
	 5+2+2+4=2-2-2-2-2-2=2+2+2+2+2=2-2+3-2-
	 2+3+2+2+3-2-3-2+2=2-4+5-3-3-
	 4+4-2-4+3-2+4=4-5+2-3+1=7-5-
	]]
	local s,c="",""
	local n,ll=nil,nil
	local ld,d=nil,"="
	local dy,l,wi=1,1,1
	for si=1,#wd do
		c = sub(wd,si,si)
		if not(c=="+" or c=="-" or c=="=") then
			s=s..c
		else
			n=tonum(s)
			ld=d
			d=c
			s=""
			if ld==d then
				l=l+(dy*-1)
				w[wi]=127-l	
				wi+=1  
			end
			for j=1,n do
				if d=="+" then
				 dy=1
				elseif d=="-" then
				 dy=-1
				elseif d=="=" then
					dy*=-1
				end
				l=l+dy
				w[wi]=127-l	
			
				wi+=1	
			end
		end
	end
	for wi=1,ww do	
	 if wi%hwr==0 then
		 l=127-w[wi]
   ls=ll
   ll=ceil(l/hhr)  
   if ls and abs(ll-ls)>1 then
    ll=ll+sgn(ll-ls)*-1
   end
	 	sw[wi\hwr]=hudy-ll
	 end
	end	
end

function add_stars()
	for s = 1,max_stars do
		add(stars, {
			rnd(ww), rnd(120-hudy)+hudy, 
			rnd(2)+10 
		})
	end
end

function make_actor(k, x, y, hit)
 local at=attrs[k]
 local a={
 	k=k,
 	c=at[2],
  x=x%ww,
  y=y,
  dx=0,
  dy=0,
  frame=0,
  t=0, 
  frames=at[5],
  w=at[3],
  h=at[4],  
  
  lazy=0,
  hit=hit,
  score=attrs[k][1],
 }
 a.yt=flr((8-a.h)/2)
 a.yb=8-a.yt 
 a.xl=ceil((8-a.w)/2)
 a.xr=8-a.xl
 
 add(actors,a)
	return a
end

function add_bullet(x, y, from, track)
	b=make_actor(bullet,x,y)
	
	if from.k==bomber then
		b.k,b.c=mine,5
	else	
		local bv=attrs[bullet][7]
		local tx,ty=pl.x,pl.y  
		-- todo if track...
	 local miss=30-min(iwave,24)
	 tx+=rnd(miss)*-sgn(pl.dx)
	 ty+=rnd(miss*0.5)*-sgn(pl.dy)
		local dst=sqrt((tx-b.x)^2+(ty-b.y)^2)
		if (dst<8) bv/=16
		b.dx=((tx-b.x)/dst)*bv
	 b.dy=((ty-b.y)/dst)*bv
	end
	b.t=t
	return b
end

sp = {
 {-1.2,-1},
 {-0.8,-1},
 
 { 0,  -1},
 { 0,  -1},
 
 { 0.8,-1},
 { 1.2,-1},

 { 1,   0},
 { 1,   0},
 
 {-1.2, 1},
 {-0.8, 1},

 { 0,   1},
 { 0,   1},
 
 { 0.8, 1},
 { 1.2, 1},
 
 {-1,   0}, 
 {-1,   0}, 
}
function add_explosion(e, reverse, speed)
	reverse=reverse or false
	local expire=particle_expire
	local pt,f=t,0
	if speed~=nil then
	 expire=player_die_expire-player_exp_delay
	 pt+=player_exp_delay
	 f=99 
	else
		speed=particle_speed
	end
 for i=1,16 do
  local x,y=e.x+4,e.y+4  
  local s,d=speed,sp[i]
  if f==99 then
			local a=i*(1/16)+rnd(15)
  	d={cos(a),sin(a)}	
  	x+=rnd(5)-rnd(5)
  	y+=rnd(5)-rnd(5)
  else
	  if d[1]==0 or d[2]==0 then
				if (f==0) s=particle_speed*0.8
	  	f=1-f 
	  end
	 end
  if reverse then
  	x+=d[1]*30
  	y+=d[2]*30
  	d[1],d[2]=-1*d[1],-1*d[2]
  end
		add(particles,{
			x=x,y=y,
			dx=d[1]*s,dy=d[2]*s,
			c=e.c, t=pt, expire=expire,
		})
	end
end

function kill_actor(e, laser, explode)
	explode=explode~=false
 if explode then
		if not(e.k==bullet or e.k==mine) then
		 add_explosion(e)
	 	if (laser) del(lasers,laser)  
	 end
	end

	del(actors, e)
	
	if demo.t==0 then
	 if (e.k~=human) add_pl_score(e.score)
		
		if e.k==lander then
		 sfx(1)
		 wave.landers_hit+=1
		 
		 if e.target~=nil then
			 if e.target.capture==capture_lifted then
			 	e.target.dy=gravity_speed
					e.target.dropped_y=e.y
			 	e.target.capture=nil
			 	sfx(5)
			 end
			end
		 
		 if wave.landers_hit%5==0 then
				if (wave.landers>0) add_enemies()
			end
		elseif e.k==mutant then
		 wave.landers_hit+=1  
		elseif e.k==baiter then
		 wave.baiters_generated-=1  
		elseif e.k==pod then
		 local r,make=flr(rnd(256)),7 
		 if r<64 then
		  make=4
		 elseif r<128 then
		  make=5
			 if (r==65) make=1
		 elseif r<172 then
		  make=6
			 if (r==129) make=2
		 end
		 if (r==173) make=3
		 make=min(make, max_swarmers-active_enemies(swarmer))
		 for sw=1,make do
			 local x,y=e.x+rnd(3),e.y+rnd(6)
				l=make_actor(swarmer,x,y)  
				l.dy=attrs[swarmer][7]/2
				if (rnd()<0.5) l.dy*=-1  
				l.lazy=rnd(64)  
			end
			sfx(11) 
		elseif e.k==swarmer then
			sfx(12) 
		elseif e.k==human then
			if e.capture~=nil then
		 	for a in all(actors) do
		 		if (a.k==lander and a.target==e) a.target=nil
		 	end
			 for plt in all(pl.target) do
		 		if (plt==e) del(pl.target,plt)
		 	end
			end
		 humans-=1
		 if humans<=0 then
		  local s=particle_speed/1.5
		  local d={rnd()-0.5,-1}
				for sx=-64,192 do
					local i=((ceil(cx+sx))%ww)+1
			  local x,y=cx+sx,w[i]  
			  if (rnd()<0.08) d,s={rnd()-0.5,-1},s+rnd()/6
					add(particles,{
						x=x,y=y,
						dx=d[1]+(abs(sx)/256)*s,dy=d[2]*s,
						c=4, t=t, expire=ground_destroy_expire,
					})				
				end
		 	music(8,0,8)  
		 	for a in all(actors) do
		 		if a.k==lander then
		 			a.k=mutant
			 		a.c=attrs[mutant][2]
			 		a.lazy=0  
						a.dy=attrs[mutant][7] 
		 		end
		 	end
				wave.mutants+=wave.landers
				wave.landers=0
		 	bombing_c=5
		 	bombing_e=ground_destroy_expire
		 	bombing_t=t 
			end
		end
		if is_wave_complete() then
		 pl.hit=t 
		 add_pl_score(humans*100*min(iwave+1,5))
			_draw=_draw_end_wave
		end
	else 
	 bombing_t=t
		demo.step_next_part+=1
	end
end

function reset_player(full)
 if full then
		pl.lives,pl.bombs=2,3
		pl.score=0
		pl.score_10k=0
 end
 cdx=0 
 bombing_e=bombing_expire
	pl.x,pl.y=cx+20,64
	pl.facing,pl.dy=1,0
	pl.thrusting,pl.birth=false,nil
	pl.target={}
end

function kill_player(e)
	old_p={pl.x,pl.y,pl.facing}
 pl.hit=t 
	sfx(3,-2) 
	music(-1) 
	sfx(4)  
	wave.t_chunk-=player_die_expire  
 lasers={}
 for i=1,16 do 
  add_explosion(pl, false, rnd()*particle_speed/16+i/16) --, player_die_expire, true)
	end 
	pl.lives-=1
	add_pl_score(25)
	
	kill_actor(e, nil, false)  
	
 for plt in all(pl.target) do
		kill_actor(plt, nil)
		del(pl.target,plt)
	end

	reset_player()

	if pl.lives<0 then
	 pl.hit=t 
		_draw=_draw_game_over
		_update60=_update60_game_over
	end
end

function add_humans()
	for h=1,humans do
	 local x=rnd(ww)  
	 local y=120-flr(rnd(4))
		h=make_actor(human,x,y,time())
		h.dx=rnd(attrs[human][7])  
		if (rnd()>0.5) h.dx=h.dx*-1
		h.capture,h.dropped_y=nil,nil
	end
	add_humans_needed=false
end


function active_enemies(include_only)
 local r=0
	for e in all(actors) do
	 if not(include_only and e.k~=include_only) then
	  if (not(e.k==baiter or e.k==bullet or e.k==mine or e.k==human)) r+=1
	 end
 end
 return r
end

function is_wave_complete()
	local r=0
 r+=active_enemies()
	r+=wave.landers+wave.bombers+wave.pods+wave.mutants
	return r==0  
end

function load_wave()
	local sw=waves[4]
	if (iwave<4) sw=waves[iwave+1]
	wave={
 	 c=wave_colours[iwave%7+1],
 		landers=sw.landers,
 		bombers=sw.bombers,
 		pods=sw.pods,	
 		
 		mutants=0,
 		
 		t=t,
 		t_chunk=t,
 		
 		landers_hit=0,  
 		
 		humans_added=nil,
	}
	wave.baiters_generated=0
	wave.swarmers_loosed=0 

	if iwave==0 or (iwave+1)%5==0 then
		wave.humans_added=max_humans-humans
		humans+=wave.humans_added
	end
	
 if humans<=0 then
 	wave.mutants+=wave.landers
 	wave.landers=0
 end
 
end

function add_enemies(ht)
 ht=ht or t 
 local sound=not(ht>t) 
 local make
	if wave.landers>0 then
	 make=min(wave.landers,5)
		for e=1,make do
			l=make_actor(lander,rnd(ww),hudy+2,ht)
			l.dy=lander_speed*lander_speed_y_factor
			l.lazy=rnd(512)  
			l.target=nil
			if true then 
				for i,a in pairs(actors) do
					if a.k==human and a.capture==nil and a.dropped_y==nil then
						l.target=a
						l.target.capture=capture_targetted
						break
					end
				end
			end
			add_explosion(l,true) 
			if (sound) sfx(2)  
		end
		wave.landers-=make
	end
	if wave.mutants>0 then
	 make=wave.mutants  
		for e=1,make do
			l=make_actor(mutant,rnd(ww),hudy+2,ht)
			l.dy=attrs[mutant][7] 
			l.lazy=rnd(64)
			add_explosion(l, true)
			if (sound) sfx(2)
		end
		wave.mutants-=make
	end
	if wave.bombers>0 then
	 make=min(wave.bombers,3) 
	 local groupx=rnd(ww)
	 local groupdx=1
		if (rnd()<0.5) groupdx*=-1
		for e=1,make do
			l=make_actor(bomber,groupx+rnd(ww/20),hudy+2+rnd(80),ht)
			l.dy=attrs[bomber][7]
			l.dx=groupdx*l.dy
 		if (rnd()<0.5) l.dy*=-1
			add_explosion(l,true)
			if (sound) sfx(2)
		end
		wave.bombers-=make
	end
 if wave.pods>0 then
	 make=min(wave.pods,4)
		for e=1,make do
			l=make_actor(pod,rnd(ww),hudy+2+rnd(30),ht)
			l.dy=attrs[pod][7]
			l.dx=l.dy/4
			add_explosion(l,true)
			if (sound) sfx(2)
		end
		wave.pods-=make
	end
 if wave.swarmers_loosed>0 then
	 make=wave.swarmers_loosed
	 local groupx=rnd(ww)
		for e=1,make do
			l=make_actor(swarmer,groupx+rnd(80),hudy+2+rnd(80),ht)
			l.dy=attrs[swarmer][7]/2
			if (rnd()<0.5) l.dy*=-1  
			l.lazy=0
		end
		wave.swarmers_loosed-=make
	end
	
 if wave.baiters_generated<max_baiters then
		local very_old=(t-wave.t)>wave_old*2
		if very_old or (wave.landers==0 and wave.bombers==0 and wave.pods==0) then
			if very_old or (wave.mutants==0) then
				local ae=active_enemies(lander)+active_enemies(mutant)
				if ae<5 or very_old then
					if t-wave.t>wave_old then
					 make=1
					 if (ae<4) wave.t_chunk=t-wave_progression+baiter_next*ae
						for e=1,make do
							l=make_actor(baiter,rnd(ww),hudy+2,ht)
							l.dy=attrs[baiter][7]/3
							l.lazy=-256
							add_explosion(l,true)
							if (sound) sfx(2)
						end
						wave.baiters_generated+=make
					end		
			 end
			end
		end
	end
end

function	reset_enemies()
	for e in all(actors) do
		if e.k==lander then
			wave.landers+=1
		elseif e.k==mutant then
			wave.mutants+=1
		elseif e.k==bomber then
			wave.bombers+=1
		elseif e.k==pod then
			wave.pods+=1
		elseif e.k == swarmer then
			wave.swarmers_loosed+=1
		end
		del(actors, e)
	end
	wave.baiters_generated=0
	add_humans_needed=true
	wave.t_chunk=t-wave_progression+wave_reset
end

function enemy_attack(e) 
	local threshold=attrs[e.k][6]
	if (threshold>=1) return
	local exs=wxtoc(e.x)
 local fire=e.k==bomber or (exs>=0 and exs<128)
	if fire then   
		if (rnd()>threshold) fire=false
		if (e.k==swarmer and (not((e.dx>0 and e.x<pl.x) or (e.dx<0 and e.x>pl.x)))) fire=false
		if fire then
		 sfx(attrs[e.k][8])  
			b=add_bullet(e.x, e.y, e, (e.k==baiter))
		end	
	end		
end


function load_highscores()
	if cart_exists then
		for hs=1,8 do
			local name=nil
			local hso=0x5e00+(hs*8)
			local c1,c2,c3=peek(hso,3)
			if c1~=0 or c2~=0 or c3~=0 then
				name=chr(c1)..chr(c2)..chr(c3)
			end
			local score=dget(hs*2+1)
			if (score~=0) add_highscore(score,name,false)
		end 
	else
	 for i in all(split(init_hs)) do
		 local s=split(i,"=")
	 	add_highscore(s[2]>>12,s[1],false)
 	end
	end
end

function add_highscore(score, name, new)
	new=new~=false
	local start_board=today
	if (not new) start_board=alltime
 for hst=start_board,alltime do
 	local hste=highscores[hst]
	 local pos=8
	 while pos>0 and score>hste[pos][2] do
		 pos-=1
	 end
	 if pos~=8 then 
		 if pos>=0 then
		 	for hs=8,pos+2,-1 do
			 	hste[hs]=hste[hs-1]
		 	end
		 	hste[pos+1]={name, score}
		 	
		 	if hst==alltime and (new or not cart_exists) then
					for hs=1,8 do
						local hso=0x5e00+(hs*8)
					 local hs_name=hste[hs][1]
					 if (hs_name ~= nil) poke(hso, ord(sub(hs_name,1,1)),ord(sub(hs_name,2,2)),ord(sub(hs_name,3,3)),ord(chr(0)))
						dset(hs*2+1, hste[hs][2])
					end 			 
		 	end
		 end	
		end
	end
end


function easeinoutquad(et)
 if (et<.5) return et*et*2
 et-=1
 return 1-et*et*2
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000bb000000bb00000099b00000b9900000bbb0000000000000000000000000000000000
00700700000000000660000008800000000000000000000000000000000fb000000fb00000b0b0b000b0b0b000bb0bb000000000000000000000000000000000
0007700000000000e66600008888000000070000000000000000000000022e0000022e000009b9000009b900000bbb0000000000000000000000000000000000
00077000000000006e66659088888880000075000000000000000000000e2e00000e2e0000b0b0b000b0b0b000b0b0b000000000000000000000000000000000
007007000d000000eee6666b88888888000700000d0000000000000000040000000440000b00b00b0b00b00b0b00b00b00000000000000000000000000000000
00000000dddd1900000000000000000000000000eed5000000000000000400000004400000000000000000000000000000000000000000000000000000000000
000000000e73dd730000000000000000000000000edd300000000000000000000000000000000000000000000000000000000000000000000000000000000000
50505005550500550055050505055055505550505055555057755555555555550000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000055b0000055b0000055b0000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000b55eb000b55eb000b55eb000000000000000000000000000000000
555555555555555555555555555555555555555555555555555555555555555500077000000e2e00000e2e00000e2e0000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550007700000b040b000b040b000b040b000000000000000000000000000000000
5555555555555555555555555555555555555555555555555555555555555555000000000b00400b0b00400b0b00400b00000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555555555555555550000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000bbbbb000bbbbb000bbbbb000000000000000000000000000000000
000b7b80000097e8000b0970000007b900000000000000000000000000000000000000000b80808b0b80808b0b08080b00000000000000000000000000000000
0099078e007b789000787eee00b0877800000000000000000000000000000000000000000ba0a0ab0b0a0a0b0b0a0a0b00000000000000000000000000000000
00007700000000e90000097000089900000000000000000000000000000000000000000000bbbbb000bbbbb000bbbbb000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000eee00000000000000000000000000000000000000000000000000
00000090000000e80000097000000778000000000000000000000000000000000000000000555e0000555e000055500000000000000000000000000000000000
0000077e00000870000000ee000009b00000000000000000000000000000000000000000005a5e00005a5e00005a5e0000000000000000000000000000000000
0000070800000000000000000000000000000000000000000000000000000000000000000055500000555e0000555e0000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000eee0000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000050a05000a050a0005050500050a050000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000e5e000005e500000e5e000005e500000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000005e5e5e5055e5e550ae5e5ea055e5e55000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000e5e000005e500000e5e000005e500000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000050a05000a050a0005050500050a050000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000088800000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000008b8b80000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000088800000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000050500000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000050500000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000aa000a00aaa000aa00000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000a8aa0aa0aa8aa0aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000a88aa0a80aa8aa0aa8aa000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000aaaaa8aa8aaa0880aa88aa00000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000aa8888aaa8aaa00008aa88aa0000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000aa88880aa88aaa00aa8aa88aa0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000aa88000aaa80aaaaaaa08aaaaa0000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000aaa80000aaa808aaaaa8088aaa80000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000008888000088880888888800888880000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000008880000088800088888000088800000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000aaaaa00aaaaaa0aaaaaa0aaaaa0aa0000a00aaaaaa00aaaaa0aaaaa00000000000000000000000000000000000000000000000000000000000000
0000000000aaaaaa00aaaaa80aaaaa00aaaaa0aaa000aa8aaaaaaa8aaaaaa8aaaaa0000000000000000000000000000000000000000000000000000000000000
000000000aaa88aa0aa88888aa88880aa88880aaaa00aa8aa888aa8aa88888aa88aa000000000000000000000000000000000000000000000000000000000000
00000000aaa88aa8aa888888aa88880aa88880aaaaa0aa8aa8888aa8aa88888aa88aa00000000000000000000000000000000000000000000000000000000000
0000000aaa888aa8aaaaaa8aaaaaa0aaaaaa00aa8aaaaa88aa888aa8aaaaa88aaaaaa00000000000000000000000000000000000000000000000000000000000
000000aaa888aa8aaaaaa88aaaaa00aaaaaa00aa88aaaaa8aa8888aa8aaaaa88aaaaaa0000000000000000000000000000000000000000000000000000000000
00000aaa8888aa8aa88888aaa8880aaa888800aa888aaaa8aa8888aa8aa88888aa8aaaa000000000000000000000000000000000000000000000000000000000
0000aaa8888aa8aa888888aa88880aaa888800aa0888aaa8aaa888aaa8aa88888aa88aaa00000000000000000000000000000000000000000000000000000000
000aaaaaaaaaa8aaaaaaa8aa8880aaaaaaaaa0aa0088aaa88aaaaaaaa8aaaaaaa8aa88aaa0000000000000000000000000000000000000000000000000000000
00aaaaaaaaaa8aaaaaaa8aaa8000aaaaaaaaa0aa00888aaa8aaaaaaaa88aaaaaaa8aa88aaa000000000000000000000000000000000000000000000000000000
0aaaaaaaaaa88aaaaaaa8aa88000aaaaaaaaa0aa00088aaa8aaaaaaa888aaaaaaa8aaa88aaa00000000000000000000000000000000000000000000000000000
08888888888888888888888800008888888880880008888888888888888888888888888888800000000000000000000000000000000000000000000000000000
08888888888888888888088800008888888880880000888808888888808888888808880888800000000000000000000000000000000000000000000000000000
08888888888088888888088800008888888880880000088808888888000888888808880088800000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000aa000a00aaa000aa0000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000a8aa0aa0aa8aa0aaaa000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000a88aa0a80aa8aa0aa8aa00000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000aaaaa8aa8aaa0880aa88aa0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000aa8888aaa8aaa00008aa88aa000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000aa88880aa88aaa00aa8aa88aa000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000aa88000aaa80aaaaaaa08aaaaa000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000aaa80000aaa808aaaaa8088aaa8000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000888800008888088888880088888000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000888000008880008888800008880000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000aaaaa00aaaaaa0aaaaaa0aaaaa0aa0000a00aaaaaa00aaaaa0aaaaa0000000000000000000000000000000000000
00000000000000000000000000000000000aaaaaa00aaaaa80aaaaa00aaaaa0aaa000aa8aaaaaaa8aaaaaa8aaaaa000000000000000000000000000000000000
0000000000000000000000000000000000aaa88aa0aa88888aa88880aa88880aaaa00aa8aa888aa8aa88888aa88aa00000000000000000000000000000000000
000000000000000000000000000000000aaa88aa8aa888888aa88880aa88880aaaaa0aa8aa8888aa8aa88888aa88aa0000000000000000000000000000000000
00000000000000000000000000000000aaa888aa8aaaaaa8aaaaaa0aaaaaa00aa8aaaaa88aa888aa8aaaaa88aaaaaa0000000000000000000000000000000000
0000000000000000000000000000000aaa888aa8aaaaaa88aaaaa00aaaaaa00aa88aaaaa8aa8888aa8aaaaa88aaaaaa000000000000000000000000000000000
000000000000000000000000000000aaa8888aa8aa88888aaa8880aaa888800aa888aaaa8aa8888aa8aa88888aa8aaaa00000000000000000000000000000000
00000000000000000000000000000aaa8888aa8aa888888aa88880aaa888800aa0888aaa8aaa888aaa8aa88888aa88aaa0000000000000000000000000000000
0000000000000000000000000000aaaaaaaaaa8aaaaaaa8aa8880aaaaaaaaa0aa0088aaa88aaaaaaaa8aaaaaaa8aa88aaa000000000000000000000000000000
000000000000000000000000000aaaaaaaaaa8aaaaaaa8aaa8000aaaaaaaaa0aa00888aaa8aaaaaaaa88aaaaaaa8aa88aaa00000000000000000000000000000
00000000000000000000000000aaaaaaaaaa88aaaaaaa8aa88000aaaaaaaaa0aa00088aaa8aaaaaaa888aaaaaaa8aaa88aaa0000000000000000000000000000
00000000000000000000000000888888888888888888888880000888888888088000888888888888888888888888888888880000000000000000000000000000
00000000000000000000000000888888888888888888808880000888888888088000088880888888880888888880888088880000000000000000000000000000
00000000000000000000000000888888888808888888808880000888888888088000008880888888800088888880888008880000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000777070700000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000707070700000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000770077700000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000707000700000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000777077700000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000007707770777007700000077077707070077070707770770000000000000000000000000000000000000000000
00000000000000000000000000000000000000070007070700070000000700070707070700070707070707000000000000000000000000000000000000000000
00000000000000000000000000000000000000070007700770070000000700077707070700077707770707000000000000000000000000000000000000000000
00000000000000000000000000000000000000070707070700070700000707070707070707070707070707000000000000000000000000000000000000000000
00000000000000000000000000000000000000077707070777077700000777070700770777070707070707000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000202020000000000000000000000000002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1011121314151513121716170000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
808182838485868788808a8b8c8d8e8f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
909192939495969780999a9b9c9d9e9f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a1a2a3a4a5a6a7a8a9aaabacadaeaf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b1b2b3b4b5b6b7b8b9babbbcbdbebf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c0c1c2c3c4c5c6c7c8c9cacbcccdcecf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d0d1d2d3d4d5d6d7d8d9dadbdcdddedf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e1e2e3e4e5e6e7e8e9eaebecedeeef00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
7103000034604356043660436604366043660435604346043360432604306042f6042e6032c6032b6032a60329603286032760326603256032460324603236032360322603226032260523605236052460525605
000100001102011020100200e0200b020090200602002020010100000000010020200402006020090200a02009020080100601003010010000000002000030000300000000000000000000000000000000000000
010300001e6501f65020650216502265023650236502264022630216301f6201c6201a6101861016610156101361012610116100f6100f6100e6100d6100d6200d6200d6200d6200e6300f630116401364013650
930400000661007610086100861006610046100461003610036100461005610086100961009610086100761005610046100361003610056100761009610096100961008610066100561004610056100661007610
590c0000166501c66020670196601c65017630126200e6100c6200f6401165013650116400f6300c620096200861008610096100c6200d6300b630076200561006610096200c6300c6300a620066100561005610
0103000031220312303123031230312202d2202c22029220282202822027220252202421023210222102121021210202101f2001e2001e2001d2001c2001b2001b2001a2001a2001a20000200082000620005200
110200002064029650326603066021650186300401000000106301663022630296401d6401063007600030100b630136401a650246501e6501164003030046000b6201d6402a650286601c660126400763001020
4902000025240282502c24027230182200f2200c2200c220092300525000200302000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
a101000022150281502b160261601b170191701a1701d15022140291302e130301402d150231601817017170171501c14022160291602f170351703b1702516018140141301513019130201301e1201312011120
a101000011150161501c1602216026140211201a12018120181301b13028130231301b110151101912011120121200e12012120121201a1102211018120131301d14025140161300c12009120061200812009120
000300003514035140351403514034140311402e1402b13026120221201e1201b12018120161401614017150191501915016140121400d1300c12000100001000c10000100001000010002100001000010000100
0002000011430114401145011440114301142011420114201143011440114401143011430114300f4400d4500c4500a4400a4400a4400a4400a4500c450104501045015400154001640016400004000040000400
0001000016250182501a2501e2502125022250252502b25023250142501425015250172501a2501d250202501f2501a25016250132500e2500020000200002000020000200002000020000200002000020000200
0002000023244292442524422244262442e2442f24427244202441e24421234232343b2033b2033a2033920338203382033720336203352033420333203332033220332203312033120531205312053120531205
00020000307041e7542375427754287542975428754237541a754127540d7240b7040970308703357033370331703307033b7033b7033a7033a7033b7033b7033b70330703317033270533705347053770538705
2a0200003c504275542c5542b5542255421554235541c5541d5543b5043a504395043750336503355033350331503305032f5032f5032e5032e5032f5032f5032f50330503315033250533505345053750538505
010400000e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2500e2501125016250172401724013240102301623016230162300a2300f2300f24006240072400a2400e250102500f250
000400000d2400d2500e250072500b2500f2500f2500f2500b2500824006240062400624007250082500b2500e2500e2500e2500e2500c2500a250082500724006240062400f2400f25008250062500b2500d250
0102000012245112451124512255152751f2751b2651425512245122451225516275202751c265162451323512235112351224513255162751a27520255002050120501205002050020500205002050020500205
300100000c4370b4370b4270b4270d4270f4371243714447184471c447204471d447134370f4370d4270d4270e43710437164471844715447114370d4370b4270a4270a42709427094370c4370f4470040700407
001000000413006130071300713005130031200212001120011200112003120041300213000130001300013000120011200312004120031200112000130001300013001130031300412003120021200112000130
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900001d4502145024450274502a4502b4502c450274501e45017450134501345015450194501e4502145026450244501f4501945016450104500c4500b4500c4500e4500f450124500f4500d4500e45000400
3d0300000027000270002700027000270002700027000270002700027000270002700027000270002700027000270002700027000270002700027000270002700027000270002700027000270002700027000270
3d0300000027000270002700027000270002700027000270002700027000270002700027000270002700027000270002700027000270002700027000270072600726007260072600726007200072000720007260
3d0300000726007260072600726007200072000720007260072600726007260072600720007200072000726007260072600726007260072000720007200072600726007260072600726007200072000720007260
3d0300000726007260072600726007200072000720007260072600726007260072600720007200072000726007260072600726007260072000720007200072600726007260072600726007200072000720007260
3c0300000726007260072600726000000000000000000000000000000000000000000000000000000000000010200072001d2030720009203000001d2031c2031c20300000092030000000000000000000000000
3d0300000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020015210152100020000200
3d0300000020000200002000020015210152100020000200002000020000200002001521015210002000020000200002000020000200152101521000200002000020000200002000020015210152100020000200
3d0300000020000200002000020015210152100020000200002000020000200002001521015210002000020000200002000020000200152101521000200002000020000200002000020015210152100020000200
3d0300000020000200002000020015210152100020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
3d0300000020000200002000020000200002000020000200002000020024200182001820000200002000020000200002000020000200002000020000200002000020000200002000020000200182101821000200
3d0300000020000200002000020000200182101821000200002000020000200002000020018210182100020000200002000020000200002001821018210002000020000200002000020000200182101821000200
3d0300000020000200002000020000200182101821000200002000020000200002000020018210182100020000200002000020000200002001821018210002000020000200002000020000200182101821000200
3d0300000020000200002000020000200182101821000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
3d030000002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002001c2101c2100020000200
3d030000002000020000200002001c2101c2100020000200002000020000200002001c2101c2100020000200002000020000200002001c2101c2100020000200002000020000200002001c2101c2100020000200
3d030000002000020000200002001c2101c2100020000200002000020000200002001c2101c2100020000200002000020000200002001c2101c2100020000200002000020000200002001c2101c2100020000200
3c030000002000020000200002001c2101c2100020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200
1303000034624356343664436644366443664435634346243362432624306242f6142e6132c6132b6132a61329613286132761326613256132461324613236132361322613226132261523625236252462525625
130200003c6243c6343c6443c6443c6443c6443c6443c6343c6343c6343b6243b6243b6233b6233a6233963338643386433764336643356433464333643336433264332633316333162531625316153161531615
2b0300002d6342e6443065431654336543465435654356543465433644326443263432633316333163331633316333163331633316333163331623316233162330623306232f6232e6252e6252e6253062531615
5b030000396343a6443c6443c6443c6443c6343c6343c6343b6343a634396343762336633356333363331633306332f6232f6232e6132e6132f6132f6132f6133062331623306353063530635306353063500000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03030000386443a6443c6503c6503c6503c6503c6503c6503c6403c6403b6403b6403b6403964038640386303763035630346303463034630336303263031630306302e6302c6302b6202a620296202861528615
__music__
00 404d4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 08424344
00 09424344
04 06424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 10144344
04 11144344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 17424344
00 181c2024
00 191d2125
00 1a1e2226
04 1b1f2327

