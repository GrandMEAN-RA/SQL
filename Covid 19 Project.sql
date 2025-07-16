/* 
Create Database
*/
CREATE DATABASE covid_19;

/* 
Data tables imported from MS Excel via python 
*/

-- Check imported data tables
SELECT * FROM covid_deaths;
SELECT * FROM covid_vaccinations;
SELECT * FROM country_indices;

-- Clone data tables
CREATE TABLE country_indiciesclone as (
SELECT
	iso_code,
    continent,
    location,
    date,
    population_density,
    stringency_index,
    gdp_per_capita,
    aged_65_older,
    aged_70_older,
    cardiovasc_death_rate,
    diabetes_prevalence,
    handwashing_facilities,
    life_expectancy,
    human_development_index
FROM country_indices);
SELECT * FROM country_indiciesclone;

CREATE TABLE covid_deathsclone as (
SELECT 
	iso_code,
    continent,
    location,
    date,
    population,
    total_cases,
    new_cases,
    total_deaths,
    new_deaths,
    reproduction_rate,
    weekly_icu_admissions,
    weekly_hosp_admissions
FROM covid_deaths);
SELECT * FROM covid_deathsclone;

CREATE TABLE covid_vaccinationsclone as (
SELECT 
	iso_code,
    continent,
    location,
    date,
    new_tests,
    total_tests,
    people_vaccinated,
    people_fully_vaccinated,
    new_vaccinations,
    total_vaccinations
FROM covid_vaccinations);
SELECT * FROM covid_vaccinationsclone;

-- Check table columns for inconsistencies
SELECT DISTINCT (location)
-- SELECT continent, location
FROM covid_deathsclone;
-- WHERE continent IS NULL;

-- SELECT DISTINCT (location)
SELECT distinct(continent), location
FROM covid_vaccinationsclone;
-- WHERE continent IS NULL;

-- SELECT DISTINCT (location)
SELECT distinct(continent), location
FROM country_indiciesclone
WHERE continent IS NULL;

-- Clean continent column: fill up null values
UPDATE covid_deathsclone
SET continent = location
WHERE location IN ('World','International','Africa','Asia','North America',
						'South America','Europe','Oceania','European Union');

UPDATE covid_vaccinationsclone
SET continent = location
WHERE location IN ('World','International','Africa','Asia','North America',
						'South America','Europe','Oceania','European Union');

UPDATE country_indiciesclone
SET continent = location
WHERE location IN ('World','International','Africa','Asia','North America',
						'South America','Europe','Oceania','European Union');

-- Clean date column: convert datetime to standard date format; Add Year column
ALTER TABLE covid_deathsclone
ADD report_date date,
ADD report_year int;

UPDATE covid_deathsclone
SET report_date = date(date);
SET report_year = year(date);

ALTER TABLE covid_vaccinationsclone
ADD report_date date;

UPDATE covid_vaccinationsclone
SET report_date = date(date);

ALTER TABLE country_indiciesclone
ADD report_date date;

UPDATE country_indiciesclone
SET report_date = date(date);

ALTER TABLE covid_deathsclone
DROP date;

ALTER TABLE covid_vaccinationsclone
DROP date;

ALTER TABLE country_indiciesclone
DROP date;

-- Covid Trends by year
DROP VIEW global_data_summary_by_year;
CREATE VIEW global_data_summary_by_year as (
	SELECT 
		location,
        report_year AS YEAR,
        MAX(population) AS Population,
		ROUND(AVG(new_cases),2) AS Avg_Daily_Cases,
		MAX(total_cases) AS Total_Cases,
		ROUND(AVG(new_deaths),2) AS Avg_Daily_Deaths,
		MAX(total_deaths) AS Total_Deaths,
        ROUND((MAX(total_cases)/MAX(population))*100,2) AS Infection_Rate_Percent,
        ROUND((MAX(total_deaths)/MAX(population))*100,2) AS Death_Rate_Percent_From_Covid,
		ROUND((MAX(Total_Deaths)/MAX(Total_Cases))*100,1) AS Likelihood_of_Deaths_From_Infection_Percent,
        MAX(reproduction_rate) AS Fertility_Rate
	FROM
		covid_deathsclone
	GROUP BY
		location,report_year);
SELECT * FROM global_data_summary_by_year;

-- Covid Trends by continent and year
SELECT *
FROM
	global_data_summary_by_year
WHERE 
	location in ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World');

-- Covid Trends by country and year
SELECT *
FROM
	global_data_summary_by_year
WHERE 
	location not in ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','International');
        
-- Likelihood of getting and dying from covid-19 infection: 
-- Total cases percent of Total deaths and total cases percent of population by continent
DROP VIEW global_data_summary;
CREATE VIEW global_data_summary AS (
	SELECT 
		location,
        MAX(population) AS Population,
		ROUND(AVG(new_cases),2) AS Avg_Weekly_Cases,
		MAX(total_cases) AS Total_Cases,
		ROUND(AVG(new_deaths),2) AS Avg_Weekly_Deaths,
		MAX(total_deaths) AS Total_Deaths,
        ROUND((MAX(total_cases)/MAX(population))*100,2) AS Infection_Rate_Percent,
        ROUND((MAX(total_deaths)/MAX(population))*100,2) AS Death_Rate_From_Covid_Percent,
		ROUND((MAX(Total_Deaths)/MAX(Total_Cases))*100,1) AS Likelihood_of_Deaths_From_Infection_Percent,
        MAX(reproduction_rate) AS Fertility_Rate
	FROM
		covid_deathsclone
	GROUP BY
		location);
SELECT * FROM global_data_summary
ORDER BY Infection_Rate_Percent DESC;

-- Likelihood of getting and dying from covid-19 infection by continent
SELECT *
FROM
	global_data_summary
WHERE 
	location in ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World');

-- Likelihood of getting and dying from covid-19 infection by country
SELECT *
FROM
	global_data_summary
WHERE 
	location not in ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World','International')
ORDER BY
	location asc;

-- Progression of Covid-19 Infections and deaths
DROP VIEW ProgressionOfCovid19InfectionsAndDeaths;
CREATE VIEW ProgressionOfCovid19InfectionsAndDeaths AS (
SELECT 
	location,report_date,new_cases,total_cases,new_deaths,total_deaths,
    round((new_cases/total_cases)*100,2) AS Spread_Rate_Percent,
    round((total_cases/population)*100,2) AS Percent_Infected,
    round((new_deaths/new_cases)*100,2) AS Inst_Death_Percent, -- Instantaneous death percent = new_deaths/new_cases
    round((total_deaths/total_cases)*100,2) AS Death_By_Infection_Percent
FROM 
	covid_deathsclone
WHERE location <> 'International');
SELECT * FROM ProgressionOfCovid19InfectionsAndDeaths;

-- Progression of Covid-19 Infections and deaths by Continent
SELECT *
FROM
	ProgressionOfCovid19InfectionsAndDeaths
WHERE 
	location in ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World')
ORDER BY
	location asc;
    
-- Progression of Covid-19 Infections and deaths by Country
SELECT *
FROM
	ProgressionOfCovid19InfectionsAndDeaths
WHERE 
	location not in ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World')
ORDER BY
	location asc;

-- Global summaries of Covid-19 Infections and deaths by date
SELECT report_date AS Date,
	SUM(new_cases) AS NewCases,MAX(total_cases) AS TotalCases,
    SUM(new_deaths) AS NewDeaths,MAX(total_deaths) AS TotalDeaths
FROM
	ProgressionOfCovid19InfectionsAndDeaths
GROUP BY
	date
ORDER BY
	report_date asc;

-- Maximum covid-19 impacts (new cases and new deaths) on a single day
DROP VIEW MaxCases;
CREATE VIEW MaxCases AS (
	SELECT max.location, max.report_date, max.new_cases
	FROM covid_deathsclone AS max
	JOIN (
		SELECT location, MAX(new_cases) AS max_new_cases
		FROM covid_deathsclone
		GROUP BY location
		) AS max_result
	ON max.location = max_result.location AND max.new_cases = max_result.max_new_cases);
SELECT * FROM MaxCases;

DROP VIEW MaxDeaths;
CREATE VIEW MaxDeaths AS (
	SELECT max.location, max.report_date, max.new_deaths
	FROM covid_deathsclone as max
	JOIN (
		SELECT location, MAX(new_deaths) AS max_new_deaths
		FROM covid_deathsclone
		GROUP BY location
		) max_result
	ON max.location = max_result.location AND max.new_deaths = max_result.max_new_deaths);
SELECT DISTINCT * FROM MaxDeaths;

-- Maximum covid-19 impacts by continent
WITH MaxImpactsContinent AS (
	SELECT * FROM MaxCases as C
    JOIN (
		SELECT location AS Place,report_date AS report__date,new_deaths
        FROM MaxDeaths) AS D
	ON 
		C.location = D.Place
	WHERE 
		C.location IN ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World'))
SELECT location,report_date,new_cases,report__date,new_deaths 
FROM MaxImpactsContinent
ORDER BY new_cases DESC;

-- Maximum covid-19 impacts by country
DROP TABLE IF EXISTS  MaxImpactsCountry;
CREATE TEMPORARY TABLE MaxImpactsCountry AS (
	SELECT * FROM MaxCases as C
    JOIN (
		SELECT location AS Place,report_date AS report__date,new_deaths
        FROM MaxDeaths) AS D
	ON 
		C.location = D.Place
	WHERE 
		C.location NOT IN ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World','International'));
SELECT distinct location,report_date,new_cases,report__date,new_deaths 
FROM MaxImpactsCountry
ORDER BY new_cases DESC;

/* 
==================================================================================================
*/
-- Covid Vaccinations
DROP VIEW global_Vaccinations;
CREATE VIEW global_Vaccinations AS 
	SELECT 
		C.continent AS Continent,C.location AS Location,C.report_date AS ReportDate,C.population AS Population,
        C.new_cases,C.total_cases,
        ROUND((C.total_cases/C.Population)*100,1) AS TotalCases_PctOfPop,
        C.new_deaths,C.total_deaths,
        ROUND((C.total_deaths/C.Population)*100,1) AS TotalDeaths_PctOfPop,
        V.new_vaccinations,
        SUM(V.new_vaccinations) OVER(PARTiTION BY C.location ORDER BY C.location,C.report_date) AS RollingNewVac,
        V.total_vaccinations,
        ROUND((V.total_vaccinations/C.total_cases)*100,1) AS TotalVaccinations_PctOfTotalCases,
        ROUND((V.total_vaccinations/C.Population)*100,1) AS TotalVaccinations_PctOfPop
	FROM
		covid_deathsclone AS C
	JOIN 
		covid_vaccinationsclone AS V
	ON
		C.location = V.location AND C.report_date = V.report_date;
SELECT DISTINCT * 
FROM global_Vaccinations
WHERE new_vaccinations is not null 
ORDER BY location,ReportDate ASC;

-- Covid Vaccinations Trends by Continent and year
SELECT DISTINCT Continent,year(ReportDate) Year,MAX(total_vaccinations) TotalVaccinations,MAX(total_cases) TotalCases,
	ROUND((MAX(total_vaccinations)/MAX(Population))*100,1) Percent_of_Pop_Vaccinated,
    ROUND((MAX(total_vaccinations)/MAX(total_cases))*100,1) Percent_of_Infected_Vaccinated
FROM global_vaccinations
WHERE total_vaccinations is not null
GROUP BY Continent, year(ReportDate)
ORDER BY Continent,Year(ReportDate);

-- Covid Vaccinations Trends by Country and year
SELECT DISTINCT Location,year(ReportDate) Year,MAX(total_vaccinations) TotalVaccinations,MAX(total_cases) TotalCases,
	ROUND((MAX(total_vaccinations)/MAX(Population))*100,1) Percent_of_Pop_Vaccinated,
    ROUND((MAX(total_vaccinations)/MAX(total_cases))*100,1) Percent_of_Infected_Vaccinated
FROM global_vaccinations
WHERE total_vaccinations is not null 
	AND Location NOT IN ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World')
GROUP BY Location, year(ReportDate)
ORDER BY Location,Year(ReportDate);

-- Covid Vaccinations Trend
SELECT DISTINCT Location,ReportDate,total_vaccinations TotalVaccinations,total_cases TotalCases,
	ROUND((total_vaccinations/Population)*100,1) Percent_of_Pop_Vaccinated,
    ROUND((total_vaccinations/total_cases)*100,1) Percent_of_Infected_Vaccinated
FROM global_vaccinations
WHERE total_vaccinations is not null 
	AND Location NOT IN ('Africa','Asia','North America','South America',
				'Oceania','Europe','European Union','World')
ORDER BY Location,Year(ReportDate);

DROP VIEW Vaccination_Effects;
CREATE VIEW Vaccination_Effects AS 
	SELECT 
		C.Continent,C.Location,C.ReportDate,C.Population,C.new_cases,C.total_cases,C.new_deaths,C.total_deaths,
        c.new_vaccinations,C.total_vaccinations,V.population_density,V.stringency_index,V.handwashing_facilities,
        V.life_expectancy,V.human_development_index
	FROM
		global_vaccinations AS C
	JOIN 
		country_indiciesclone AS V
	ON
		C.location = V.location AND C.ReportDate = V.report_date;
SELECT DISTINCT * 
FROM Vaccination_Effects
WHERE new_vaccinations is not null
ORDER BY location,ReportDate ASC;

-- Covid-19 Risk Factors
-- create procedure to calculate correlation
DELIMITER $$

CREATE PROCEDURE correlation(
    IN table_name VARCHAR(64),
    IN col_x VARCHAR(64),
    IN col_y VARCHAR(64)
)
BEGIN
    SET @sql = CONCAT(
        'SELECT 
            (COUNT(*) * SUM(', col_x, ' * ', col_y, ') - SUM(', col_x, ') * SUM(', col_y, ')) / 
            SQRT(
                (COUNT(*) * SUM(', col_x, ' * ', col_x, ') - POWER(SUM(', col_x, '), 2)) * 
                (COUNT(*) * SUM(', col_y, ' * ', col_y, ') - POWER(SUM(', col_y, '), 2))
            ) AS correlation
        FROM ', table_name, '
        WHERE ', col_x, ' IS NOT NULL AND ', col_y, ' IS NOT NULL'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- Correlation between total cases and population density
CALL correlation('vaccination_effects', 'total_cases', 'population_density');

-- Correlation between total cases and Stringency Index
CALL correlation('vaccination_effects', 'total_cases', 'stringency_index');

-- Correlation between total cases and Handwashing facilities 
CALL correlation('vaccination_effects', 'total_cases', 'handwashing_facilities');

-- Correlation between total cases and Human Development Index
CALL correlation('vaccination_effects', 'total_cases', 'human_development_index');

-- Correlation between total cases and Total_Vaccinations
CALL correlation('vaccination_effects', 'total_cases', 'total_vaccinations');






