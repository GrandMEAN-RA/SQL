CREATE DATABASE covid_19_updated;

/*
Data tables imported from MS-Excel via python
*/

-- Check imported data tables
SELECT * FROM dailydata;
SELECT * FROM mdeathbyage;
SELECT * FROM vacuptake;

-- Extract Columns to be used in a view
DROP VIEW daily_covid_data;
CREATE VIEW daily_covid_data AS
	SELECT
		WHO_region,country_code,country,date(date_reported) AS Report_Date,year(Date_reported) AS Year,month(Date_reported) AS Month,
        New_cases,Cumulative_cases,new_deaths,cumulative_deaths
	FROM
		dailydata;
SELECT * FROM daily_covid_data;

DROP VIEW death_by_age;
CREATE VIEW death_by_age AS
	SELECT
		country_code,country,year,month,agegroup,deaths
	FROM
		mdeathbyage;
SELECT * FROM death_by_age;
        
DROP VIEW vaccine;
CREATE VIEW vaccine AS
	SELECT
		country__code,covid_vaccine_adm_tot_doses AS Total_Vaccines,date(covid_vaccine_date_intro_first) AS Intro_Date,
        date(covid_vaccine_date_report_tot_last) AS Report_Date,
        date(date) AS Date
	FROM
		vacuptake;
SELECT * FROM vaccine;

-- Rolling Monthly Total Vaccinations
DROP VIEW rollingvaccines;
CREATE VIEW rollingvaccines AS
	SELECT 
		country__code,Date,Year,Month,Total_vaccines,Rolling_YearlyTotal,Rolling_CountryTotal,
		ROUND((Total_vaccines/(SUM(Total_vaccines) OVER(PARTITION BY country__code,Year ORDER BY Year)))*100,1) AS PercentOf_YearlyTotal,
		ROUND((Total_vaccines/(SUM(Total_vaccines) OVER(PARTITION BY country__code)))*100,1) AS PercentOf_CountryTotal
	FROM (
		SELECT 
			country__code,date AS Date,Year(Date) AS Year,month(Date) AS Month,Total_vaccines,
			SUM(Total_Vaccines) OVER(PARTITION BY country__code,Year(Date) ORDER BY date) AS Rolling_YearlyTotal,
			SUM(Total_Vaccines) OVER(PARTITION BY country__code ORDER BY date) AS Rolling_CountryTotal
		FROM
			vaccine) AS A
	ORDER BY
		country__code,year,Date ASC;
SELECT * FROM rollingvaccines;

DROP VIEW rolling;
CREATE VIEW rolling AS
	SELECT DISTINCT 
		country_code,country,year(report_date) AS YEAR,month(report_date) AS Month,
		SUM(new_cases)  AS New_Cases,
        SUM(new_deaths) AS New_Deaths
	FROM
		daily_covid_data
	GROUP BY
		country_code,country,year(report_date),month(report_date);
	SELECT * FROM rolling;

DROP VIEW rollingcases;
CREATE VIEW rollingcases AS
	SELECT 
		country_code,country,year,month,new_cases,Rolling_Yearly_Cases,Rolling_Country_Cases,
		ROUND((new_cases/(SUM(new_cases) OVER(PARTITION BY country,Year)))*100,1) AS CasesPercentOf_YearlyTotal,
		ROUND((new_cases/(SUM(new_cases) OVER(PARTITION BY country)))*100,1) AS CasesPercentOf_CountryTotal,
		new_deaths,
		Rolling_Yearly_Deaths,
		Rolling_Country_Deaths,
		ROUND((new_deaths/(SUM(new_cases) OVER(PARTITION BY country,Year)))*100,1) AS DeathsPercentOf_YearlyTotal,
		ROUND((new_deaths/(SUM(new_cases) OVER(PARTITION BY country)))*100,1) AS DeathsPercentOf_CountryTotal
	FROM (
		SELECT DISTINCT
			country_code,country,Year,Month,New_Cases,
			SUM(new_cases) OVER(PARTITION BY country,year ORDER BY Month) AS Rolling_Yearly_Cases,
			SUM(new_cases) OVER(PARTITION BY country ORDER BY Year,Month) AS Rolling_Country_Cases,
			New_Deaths,
			SUM(new_deaths) OVER(PARTITION BY country,year ORDER BY Month) AS Rolling_Yearly_Deaths,
			SUM(new_deaths) OVER(PARTITION BY country ORDER BY Year,Month) AS Rolling_Country_Deaths
		FROM 
			rolling) AS A
	ORDER BY
		country_code,country,year,month ASC;
SELECT * 
FROM rollingcases
ORDER BY country_code,country,year,month ASC;

DROP VIEW vaccine_effects;
CREATE VIEW vaccine_effects AS
	SELECT 
		country,year,month,total_cases,total_deaths,total_vaccinated,
        ROUND((total_deaths/total_cases)*100,2) AS DeathsPct_ofTotalCases,
        ROUND((total_vaccinated/total_cases)*100,2) AS VaccinatedPct_ofTotalCases
	FROM (
		SELECT
			C.country_code,C.country,C.Year,C.Month,C.Rolling_Country_Cases AS Total_Cases,
			C.Rolling_Country_Deaths AS Total_Deaths,
			COALESCE(V.Rolling_CountryTotal) AS Total_Vaccinated
		FROM
			rollingcases AS C
		LEFT JOIN 
			rollingvaccines AS V
		ON
			C.country_code = LEFT(V.country__code,2) AND C.Year = V.Year AND C.Month = V.Month
		ORDER BY
			C.country,c.year,c.month ASC) AS A;
SELECT * FROM vaccine_effects;



