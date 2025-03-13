--## Question 1: Rankings
--#### Question 1a: Warmup Question
--Write a query which retrieves each teamid and number of wins (w) for the 2016 season. Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. Compare the output from these three functions. What do you notice?

SELECT 
    teamid,
	w,
	ROW_NUMBER() OVER (ORDER BY w DESC) AS row_number,
	RANK() OVER (ORDER BY w DESC) AS rank,
	DENSE_RANK() OVER (ORDER BY w DESC) AS dense_rank
FROM teams
WHERE yearid = 2016;

--the row number function returns the exact ordering of the row, rank function returns the ranking of size of wins with ties being the same rank but skipping the next rank number, and dense_rank function returns the ranking of size of wins with ties being the same rank but not skipping the next rank number.

--#### Question 1b: 
--Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? A team's division is indicated by the divid column in the teams table.

WITH CTE AS (SELECT 
     teamid,
	 divid,
	 w,
	 DENSE_RANK() OVER (PARTITION BY divid, lgid, yearid ORDER BY w) AS dense_rank
FROM teams)

SELECT teamid, COUNT(dense_rank) AS last_place_count
FROM CTE
WHERE dense_rank = 1
GROUP BY teamid
ORDER BY last_place_count DESC;

--## Question 2: Cumulative Sums
--#### Question 2a: 
--Barry Bonds has the record for the highest career home runs, with 762. Write a query which returns, for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. (Barry Bonds' playerid is bondsba01.)

SELECT
     yearid,
	 COUNT(yearid) OVER(ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_season,
	 SUM(hr) OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS season_total_hr
FROM batting
WHERE playerid = 'bondsba01'
GROUP BY yearid,hr;

--#### Question 2b:
--How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? For this question, we will consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of seasons into his career. 
WITH CTE_0 AS(SELECT yearid, playerid, SUM(hr) AS hr
FROM batting
GROUP BY yearid, playerid),

 CTE_1 AS (SELECT
     playerid,
	 yearid,
	 COUNT(yearid)OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_seasons,
     SUM(hr)OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_hr
FROM CTE_0),

CTE_2 AS (SELECT
     yearid,
	 COUNT(yearid) OVER(ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_season,
	 SUM(hr) OVER (ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS season_total_hr
FROM CTE_0
WHERE playerid = 'bondsba01')

SELECT COUNT (playerid)
FROM CTE_1
INNER JOIN CTE_2
ON CTE_1.running_total_seasons = CTE_2.total_season
WHERE running_total_hr > season_total_hr
AND running_total_seasons = total_season
AND CTE_1.yearid = 2016;


--#### Question 2c: 
--Were there any players who 20 years into their career who had hit more home runs at that point into their career than Barry Bonds had hit 20 years into his career? 
WITH CTE_0 AS(SELECT yearid, playerid, namefirst|| ' ' ||namelast AS full_name, SUM(hr) AS hr
FROM batting
INNER JOIN people
USING(playerid)
GROUP BY yearid, playerid, namefirst, namelast),


CTE_1 AS (SELECT
     playerid,
	 yearid,
	 full_name,
	 COUNT(yearid)OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_seasons,
     SUM(hr)OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_hr
FROM CTE_0),

CTE_2 AS (SELECT
     yearid,
	 COUNT(yearid) OVER(ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS barry_bonds_total_season,
	 SUM(hr) OVER (ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total_hr_barry_bonds
FROM CTE_0
WHERE playerid = 'bondsba01')

SELECT full_name, running_total_hr, running_total_seasons
FROM CTE_1
INNER JOIN CTE_2
ON CTE_1.running_total_seasons = CTE_2.barry_bonds_total_season
WHERE running_total_hr > running_total_hr_barry_bonds
AND running_total_seasons = 20
AND barry_bonds_total_season =20;

--## Question 3: Anomalous Seasons
--Find the player who had the most anomalous season in terms of number of home runs hit. To do this, find the player who has the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs if we consider the 5-year window centered at that year (the window should include that year, the two years prior and the two years after).
 WITH CTE_1 AS(SELECT
     playerid,
	 namefirst|| ' ' ||namelast AS full_name,
	 yearid,
     hr
FROM batting
INNER JOIN people
USING(playerid)),

CTE_2 AS(SELECT
     playerid,
	 yearid,
     AVG(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS running_avg
FROM batting)

SELECT
     full_name,
	 yearid,
	 hr,
	 running_avg,
	 hr - running_avg AS hr_avg_gap
FROM CTE_1
INNER JOIN CTE_2
USING(playerid, yearid)
ORDER BY hr_avg_gap DESC;

--## Question 4: Players Playing for one Team
--For this question, we'll just consider players that appear in the batting table.
--#### Question 4a: 
--Warmup: How many players played at least 10 years in the league and played for exactly one team? (For this question, exclude any players who played in the 2016 season). Who had the longest career with a single team? (You can probably answer this question without needing to use a window function.)

WITH CTE_1 AS (SELECT playerid, COUNT(DISTINCT yearid) AS year_count, MAX(yearid) AS max_year
FROM batting
WHERE playerid NOT IN 
   (SELECT playerid
    FROM batting
    WHERE yearid = 2016)
GROUP BY playerid
HAVING COUNT(DISTINCT yearid) >= 10
AND COUNT(DISTINCT teamid) = 1)

SELECT DISTINCT ON (playerid) playerid, namefirst|| ' ' ||namelast AS full_name, year_count, teams.name AS team_name
FROM batting
INNER JOIN CTE_1
USING(playerid)
INNER JOIN teams
USING(teamid, yearid)
INNER JOIN people
USING(playerid);
 
--#### Question 4b: 
--Some players start and end their careers with the same team but play for other teams in between. For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants for 7 seasons before returning to the Oakland Athletics for his final season. How many players played at least 10 years in the league and start and end their careers with the same team but played for at least one other team during their career? For this question, exclude any players who played in the 2016 season.

WITH CTE_1 AS (SELECT playerid, COUNT(DISTINCT yearid) AS year_count, COUNT(DISTINCT teamid) AS team_count
FROM batting
WHERE playerid NOT IN 
   (SELECT playerid
    FROM batting
    WHERE yearid = 2016)
GROUP BY playerid
HAVING COUNT(DISTINCT yearid) >= 10
AND COUNT(DISTINCT teamid) > 1),

CTE_2 AS (
SELECT 
     DISTINCT playerid, 
	 year_count, 
	 team_count,
	 FIRST_VALUE(teamid) OVER(PARTITION BY playerid ORDER BY yearid) AS first_team,
	 FIRST_VALUE(teamid) OVER(PARTITION BY playerid ORDER BY yearid DESC) AS last_team
FROM batting
INNER JOIN CTE_1
USING(playerid))

SELECT namefirst|| ' ' ||namelast AS full_name, year_count, team_count, first_team, last_team
FROM CTE_2
INNER JOIN people
USING(playerid)
WHERE first_team = last_team
ORDER BY year_count DESC;

--## Question 5: Streaks
--#### Question 5a: 
--How many times did a team win the World Series in consecutive years?

WITH CTE_1 AS (SELECT
     teamid,
	 yearid,
	 wswin,
	 LAG(wswin) OVER (PARTITION BY teamid ORDER BY yearid) AS win_prev,
	 LEAD(wswin) OVER (PARTITION BY teamid ORDER BY yearid) AS win_following
FROM teams)

SELECT *
FROM CTE_1
WHERE win_prev = 'Y'
AND wswin = 'Y'
ORDER BY yearid;

--#### Question 5b: 
--What is the longest steak of a team winning the World Series? Write a query that produces this result rather than scanning the output of your previous answer.

WITH CTE_1 AS (
SELECT
     teamid,
	 yearid,
	 wswin,
	 LAG(teamid)OVER(ORDER BY yearid) AS prev_team
FROM teams
WHERE wswin = 'Y'
),

CTE_2 AS (
SELECT
     teamid,
	 yearid,
	 CASE WHEN prev_team = teamid THEN 0
	      WHEN prev_team <> teamid THEN 1 END AS prev_match
FROM CTE_1
),

CTE_3 AS (SELECT
     teamid,
	 yearid,
	 SUM(prev_match)OVER(ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS streaks
FROM CTE_2)

SELECT teamid, MIN(yearid) AS min_year, MAX(yearid) AS max_year, streaks
FROM CTE_3
GROUP BY teamid, streaks
HAVING COUNT(streaks) >= 2
ORDER BY COUNT(streaks) DESC;


--#### Question 5c: 
--A team made the playoffs in a year if either divwin, wcwin, or lgwin will are equal to 'Y'. Which team has the longest streak of making the playoffs? 

WITH CTE_1 AS (
SELECT
     name,
     teamid,
	 yearid,
	 CASE WHEN divwin = 'Y' OR wcwin = 'Y' OR lgwin = 'Y' THEN 'Y' ELSE 'N' END AS playoff
FROM teams
)

,CTE_2 AS (
SELECT
     name,
     teamid,
	 yearid,
	 playoff,
	 LAG(playoff)OVER(PARTITION BY teamid ORDER BY yearid) AS prev_playoff
FROM CTE_1
ORDER BY teamid, yearid
),

CTE_3 AS (SELECT
     name,
     teamid,
	 yearid,
	 playoff,
	 CASE WHEN prev_playoff = 'Y' THEN 0
	      WHEN prev_playoff <> 'Y' THEN 1 END AS prev_match	
FROM CTE_2
),

CTE_4 AS (
SELECT
     name,
     teamid,
	 yearid,
	 playoff,
     SUM(prev_match)OVER(PARTITION BY teamid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS streaks
FROM CTE_3)

SELECT name, teamid, MIN(yearid), MAX(yearid), COUNT(*) AS streak_length
FROM CTE_4
WHERE playoff = 'Y'
GROUP BY name, teamid, streaks
HAVING COUNT(*) > 1
ORDER BY COUNT(streaks) DESC;

--#### Question 5d: 
--The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, does this change your answer for the previous part?

WITH CTE_1 AS (
SELECT
     name,
     teamid,
	 yearid,
	 CASE WHEN divwin = 'Y' OR wcwin = 'Y' OR lgwin = 'Y' THEN 'Y' ELSE 'N' END AS playoff
FROM teams
WHERE yearid <> 1994
)

,CTE_2 AS (
SELECT
     name,
     teamid,
	 yearid,
	 playoff,
	 LAG(playoff)OVER(PARTITION BY teamid ORDER BY yearid) AS prev_playoff
FROM CTE_1
ORDER BY teamid, yearid
),

CTE_3 AS (SELECT
     name,
     teamid,
	 yearid,
	 playoff,
	 CASE WHEN prev_playoff = 'Y' THEN 0
	      WHEN prev_playoff <> 'Y' THEN 1 END AS prev_match	
FROM CTE_2
),

CTE_4 AS (
SELECT
     name,
     teamid,
	 yearid,
	 playoff,
     SUM(prev_match)OVER(PARTITION BY teamid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS streaks
FROM CTE_3)

SELECT name, teamid, MIN(yearid), MAX(yearid), COUNT(*) AS streak_length
FROM CTE_4
WHERE playoff = 'Y'
GROUP BY name, teamid, streaks
HAVING COUNT(*) > 1
ORDER BY COUNT(streaks) DESC;

--## Question 6: Manager Effectiveness
--Which manager had the most positive effect on a team's winning percentage? To determine this, calculate the average winning percentage in the three years before the manager's first full season and compare it to the average winning percentage for that manager's 2nd through 4th full season. Consider only managers who managed at least 4 full years at the new team and teams that had been in existence for at least 3 years prior to the manager's first full season.
SELECT *
FROM managers;


WITH CTE_1 AS(SELECT
     playerid,
	 teamid,
	 MIN(yearid) AS first_season
FROM managers
INNER JOIN teams
USING(teamid, yearid)
GROUP BY playerid, teamid
HAVING COUNT(DISTINCT yearid) >= 4)

,CTE_2 AS (
SELECT
     playerid,
	 teamid
FROM CTE_1
INNER JOIN teams
USING(teamid)
GROUP BY playerid, teamid, first_season
HAVING MIN(yearid) + 3 <= first_season
)


,CTE_3 AS (
SELECT
     playerid,
	 yearid,
	 AVG(CAST(w AS NUMERIC)/CAST(g AS NUMERIC)) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS before_avg,
     AVG(CAST(w AS NUMERIC)/CAST(g AS NUMERIC)) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN 2 FOLLOWING AND 4 FOLLOWING) AS after_avg
FROM managers
INNER JOIN CTE_2
USING(playerid, teamid)
)

SELECT
     namefirst|| ' ' ||namelast AS full_name,
	 before_avg,
	 after_avg,
	 after_avg - before_avg AS avg_diff
FROM CTE_3
INNER JOIN people
USING(playerid)
ORDER BY avg_diff DESC;