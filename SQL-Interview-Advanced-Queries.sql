-- 1. Employees earning > 9000 with department

SELECT e.first_name,e.last_name,e.salary 
FROM employees e JOIN departments d 
ON e.department_id=d.department_id
WHERE e.salary>9000; 

-- 2. Departments having more than 3 employees

SELECT department_id, COUNT(*) AS emp_count
FROM employees
GROUP BY department_id
HAVING COUNT(*) > 3; 

-- 3. Employees hired after 2020-01-01

SELECT first_name,hire_date
FROM employees
WHERE hire_date>'2020-01-01';

-- 4. Names containing 'an' ordered by last name

SELECT first_name,last_name 
FROM employees
WHERE first_name LIKE '%an%'
ORDER BY last_name;

-- 5. Salary difference from company average

SELECT first_name,salary,
    salary - (SELECT AVG(salary) FROM employees) AS diff_from_avg
FROM employees;

-- 6. Employee count per location

SELECT l.location_id,l.city,count(e.emp_id) AS Emp_Count
FROM employees e 
JOIN departments d ON e.department_id=d.department_id 
JOIN locations l ON d.location_id=l.location_id
GROUP BY l.location_id,l.city;

-- 7. Count distinct job roles

SELECT Count(distinct job_id) AS Distint_Jobs
FROM employees;

-- 8. Categorize employees by salary

SELECT first_name,salary,
    CASE
        WHEN salary > 10000 THEN 'Higher Salary'
        WHEN salary BETWEEN 5000 AND 10000 THEN 'Medium Salary'
        ELSE 'Lower Salary'
    END AS Salary_Category
FROM employees;

-- 9. Full name column

SELECT first_name,last_name,CONCAT(first_name,' ',last_name) AS Full_Name
FROM employees;

-- 10. Average salary per department (2 decimals)

SELECT department_id, ROUND(AVG(salary),2)
FROM employees
GROUP BY department_id;

-- Using JOINS

SELECT e.department_id,ROUND(AVG(e.salary),2)
FROM employees e 
JOIN departments d ON e.department_id = d.department_id
Group By e.department_id;

-- 11. Employees working in location 1700

SELECT first_name,last_name
FROM employees
WHERE department_id IN (
	SELECT department_id FROM departments WHERE location_id = 1700
);

-- 12. Sort by dept, salary DESC () 

SELECT*FROM employees ORDER BY department_id,salary DESC;

-- 13. Departments without employees

SELECT d.department_id,d.department_name
FROM departments d LEFT JOIN employees e 
ON d.department_id=e.department_id
WHERE  e.emp_id IS NULL;

-- 14. UNION example

SELECT job_id from employees
UNION
SELECT job_id from jobs;

-- 15. Top 5 salaries

SELECT first_name, salary
FROM employees
ORDER BY salary DESC
LIMIT 5;

-- 16. Count high/low earners

SELECT
    COUNT(CASE WHEN salary > 10000 THEN 1 END) AS high_earners,
    COUNT(CASE WHEN salary <= 10000 THEN 1 END) AS low_earners
FROM employees;

-- 17. Departments ordered by average salary

SELECT department_id,AVG(salary) AS Avg_sal
FROM employees
GROUP BY department_id
ORDER BY Avg_sal DESC;

-- 18. Three-table join

SELECT e.first_name,j.job_title,d.department_name
FROM employees e 
JOIN jobs j ON e.job_id=j.job_id
JOIN departments d ON e.department_id=d.department_id;

-- 19. Employee with manager name

SELECT e.first_name AS employee, m.first_name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;

-- 20. List employees per department

SELECT d.department_name,
       GROUP_CONCAT(CONCAT(e.first_name, ' ', e.last_name) SEPARATOR ', ') AS employees
FROM employees e
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.department_name;