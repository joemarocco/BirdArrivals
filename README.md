Climate & Spring Bird Arrivals in the northern Adirondacks  Joe Marocco

Why I started this project
==========================
In the northern Adirondacks, where I live, early spring is a fragile, shifting season: one day is bright and warm - almost short-sleeve weather; the next the temperatures drop and a spring nor’easter hits. The arrival of the robins brings hope that the snow will finally start to melt and winter will soon end.

Over the years I began to wonder whether climate change was having a measurable impact on bird arrival dates. Were robins actually arriving earlier? Were snow conditions shifting in ways I could detect? And what about other migratory species that return first to my area every spring to breed?

This project had its genesis in that curiosity.

It’s not meant to be a definitive scientific paper. It’s a personal exploration — a blend of data analysis, local natural history, and a desire to better understand the place where I live.

What this project does
======================
In simple terms, I did three things:

1. Identified a handful of early-spring, locally breeding migrants
I focused on species I see (or try to see) every spring, and each one breeds on my 55 acre property:
	•	American Robin  
	•	Eastern Phoebe  
	•	Blue-headed Vireo  
	•	Hermit Thrush  
	•	Yellow-rumped Warbler  
These are birds that respond, in different ways, to snowmelt, early warmth, and food availability.

2. Pulled ~20 years of eBird records for Franklin County

I quickly discovered something important:  eBird data before 2005 is extremely sparse and misleading in this region.  Some years show birds arriving in June simply because there were no spring checklists that year.
So I made a decision that shapes everything downstream:  I restricted the analysis to 2005–present, when local birding effort becomes reliable enough to interpret.

3. Combined arrival data with daily climate records
I used the Tupper Lake GHCN station (Tupper Lake is about 40 minutes from my house, but it is very close in climate) and built a small set of climate indicators:
	•	Mean early-spring temperature  
	•	Growing degree days  
	•	Freeze–thaw cycles  
	•	Snow depth  
	•	Snowmelt timing  
	•	First sustained thaw  
Then I looked at which of these variables best explained variation in arrival dates.



What I found (in plain language)
================================

Robins
------
By far the clearest signal: Warm early springs bring robins in earlier — about 3 days earlier per +1°C.
Snow depth matters, but not as much as temperature.

Other species
-------------
Each species responded differently, and often less strongly. Some arrival patterns were noisy, which makes sense: migration isn’t driven by local climate alone.
Still, across species, the variables that consistently mattered most were:

-Spring warmth -Snow depth or persistence  
It turns out my on-the-ground observations over the years align perfectly with the data: birds come when the landscape opens up and warms enough to support them.


What this project isn’t
=======================

I don’t claim to be modeling continental-scale migration. I’m not asserting causation. I’m not producing publishable ecology.
This is a local, personal study — one county, one climate station, a handful of species — built because I wanted to understand the place where I live a little bit better.



What this project is
====================

A record of my own learning A chance to build skills in R, modeling, and visualization A way of paying more attention to the rhythms of the land A starting point for deeper questions  
This is also my first time blending eBird and NOAA data in a structured analysis, and I learned more from this than from any textbook exercise.


How I built this
================
The analysis is written in R using:

tidyverse (data wrangling and plotting)  auk (filtering the eBird Basic Dataset)  broom (model summaries)  visreg (partial regression visualization)  
The code is heavily commented because I wanted to understand why each step was there, not just what it did.
****I did use AI tools (like ChatGPT) as a coding assistant**** — mostly for:

boilerplate  syntax reminders  debugging  improving clarity  
But all decisions about modeling, filtering, interpretation, and structure were my own. The project reflects my understanding, not anyone else’s.


Where this could go next
========================
Adding more species  Including more climate stations for spatial robustness  Exploring non-linear models (GAMs)  Looking at departure dates or breeding phenology  Visualizing checklist coverage over time  Writing a short narrative essay interpreting the ecological implications  

