Climate & Spring Bird Arrivals in the northern Adirondacks
 Joe Marocco

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

I quickly discovered something important:
 eBird data before 2005 is extremely sparse and misleading in this region.
 Some years show birds arriving in June simply because there were no spring checklists that year.
So I made a decision that shapes everything downstream:
 I restricted the analysis to 2005–present, when local birding effort becomes reliable enough to interpret.

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

-Spring warmth
-Snow depth or persistence


It turns out my on-the-ground observations over the years align perfectly with the data: birds come when the landscape opens up and warms enough to support them.


What this project isn’t
=======================

I don’t claim to be modeling continental-scale migration.
I’m not asserting causation.
I’m not producing publishable ecology.
This is a local, personal study — one county, one climate station, a handful of species — built because I wanted to understand the place where I live a little bit better.



What this project is
====================

A record of my own learning
A chance to build skills in R, modeling, and visualization
A way of paying more attention to the rhythms of the land
A starting point for deeper questions


This is also my first time blending eBird and NOAA data in a structured analysis, and I learned more from this than from any textbook exercise.


How I built this
================
The analysis is written in R using:

tidyverse (data wrangling and plotting)

auk (filtering the eBird Basic Dataset)

broom (model summaries)

visreg (partial regression visualization)


The code is heavily commented because I wanted to understand why each step was there, not just what it did.
****I did use AI tools (like ChatGPT) as a coding assistant**** — mostly for:

boilerplate

syntax reminders

debugging

improving clarity


But all decisions about modeling, filtering, interpretation, and structure were my own. The project reflects my understanding, not anyone else’s.

Methods
=======

<u>How eBird data were filtered</u>

I downloaded bird sighting data from eBird for Franklin County, NY for all species and all dates. I defined a small set of target species based on my own observations and knowledge of local spring birds. I chose five species that: 1) I see on my property every year, 2) breed here, 3) are migratory. These were: American Robin, Blue-headed Vireo, Hermit Thrush, Yellow-rumped Warbler, and Eastern Phoebe. I then filtered the eBird data to include only these species.


<u>How first-arrival DOY was computed</u>


I computer first-arrival DOY with the following method: 
1) I defined a spring arrival window of March 1 - June 30 to match the phenology of my area
2) I restrained the data to 2005 and later (see below)
3) I grouped by year and calculated the min of the date of the observations for each species

<u>Why pre-2005 was dropped</u>

Although the dataset included sighting going back to 1974, I soon realized that this older data was not complete enough to use for FOY (first of year) determinations. For example, from 1974-2004, the first sighting of a robin in my county ranged from late March (reasonable) to late June (unreasonable). So, I decided to drop pre-2005 data for my purposes.

<u>How climate variables were derived</u>

Using the Tupper Lake, NY weather station, which has weather data from the late 1800s to present day, I calculated the following metrics:

1) Estimated average daily temperatures (tmean): (TMAX-TMIN)/2
2) Spring mean temp: I grouped by year and calculated the mean of daily tmean for Feb - April
3) Growing degree days: Using tmean, I calculated GDD with a base of 0 degrees C.
4) Freeze-thaw days: using the TMIN and TMAX data, I looked for days with TMIN<=1 and TMAX >=-1. This captures days with freezing nights and thawing days — classic maple-sap and early-season phenology conditions.
5) Mean snow depth: average snow depth for Feb and March, the months in which snow cover has the most impact on migration.
6) Date of first bare ground: I looked for the first day between Jan and May with 0 cm snow depth. Bare ground is vital for ground feeding birds like the robin, although the ground does not have to be totally bare for them to return to their breeding grounds. 
7) Snow persistence: this is the number of days between Jan and Apr with a snow depth of > 10cm.
8) First sustained thaw: the first stretch of >=3 days of TMIN > 0.

Once these variables were computed, they were joined with the species arrival data into one table for analysis.

<u>Why certain models were chosen</u>

The question I wanted to answer here was: for each species, which single climate variable best predicts year-to-year variation in arrival DOY?
To answer it, I:

1) fit a separate linear model for each (species, predictor) pair:  doy ~ predictor
2) recorded slope, p-value, R^2, AIC
3) defined the "best" predictor as the one with the lowest AIC per species.

<u>How to interpret slopes</u>

Negative slope: birds arrive earlier when the climate variable increases.
Example: a slope of –3 for spring temperature means a +1°C warmer spring is associated with birds arriving about 3 days earlier.
Positive slope: birds arrive later when the variable increases.
Example: a slope of +2 for snow depth means deeper snow is associated with birds arriving 2 days later.
The magnitude of the slope indicates the strength of the relationship, but it should be interpreted in the context of natural variability and sample size.

<u>How to interpret partial regression (visreg plots)</u>

Arrival dates change over time for many reasons, including long-term trends.
A partial regression plot shows the effect of one climate variable after removing the influence of other variables, such as year.
The x-axis shows residual snow depth (the part of snow depth not explained by year).
The y-axis shows residual arrival DOY (the part of arrival timing not explained by year).
The line shows the effect of snow depth independent of long-term trends.
If the line slopes downward then even after accounting for year-to-year trends, birds still arrive earlier in years with lower snow depth (or higher temperature, etc.).
This helps separate true biological relationships from simple long-term trends or sampling artifacts.


Where this could go next
========================
Adding more species

Including more climate stations for spatial robustness

Exploring non-linear models (GAMs)

Looking at departure dates or breeding phenology

Visualizing checklist coverage over time

Writing a short narrative essay interpreting the ecological implications



