### ANALYZING TRAFFIC SOURCES
-- ===============================================================
-- Website Analysis SQL Script
-- ===============================================================
-- Description : This script performs various analysis on website
--               data to extract insights and generate reports.
-- ===============================================================
-- Author: Rupsa Chaudhuri
-- ===============================================================

/*  TRAFFIC SOURCE ANALYSIS
Traffic source analysis is about understanding where your customers are 
coming from and which channels are driving the highest quality traffic.
*/

#1. Finding top traffic sources
SELECT 
    utm_source,
    utm_campaign,
    http_referer,
    COUNT(DISTINCT website_session_id) AS sessions
FROM
    website_sessions
WHERE YEAR(created_at)!= '2015'
GROUP BY 1,2,3
ORDER BY 4 DESC;
# gsearch non-brand seems to be a major traffic driver(247,564 sessions), followed by traffic from bsearch/non-brand(48,072 sessions).Direct traffic comes at third(32793).

/*
2. Monthly trends for Gsearch, alongside monthly trends for each of our other channels.
*/ 
    
SELECT 
    YEAR(created_at) AS Year,
    COUNT(DISTINCT case when utm_source='gsearch' then website_session_id else null end) AS gsearch_sessions,
    COUNT(DISTINCT case when utm_source='bsearch' then website_session_id else null end) AS bsearch_sessions,
    COUNT(DISTINCT case when utm_source is null and http_referer is not null then website_session_id else null end) AS organic_search_sessions,
    COUNT(DISTINCT case when utm_source is null and http_referer is null then website_session_id else null end) AS direct_search_sessions
FROM
    website_sessions 
WHERE YEAR(created_at)!= '2015'
GROUP BY 1;
/* 
Gsearch traffic seems dominant with consistent increase in sessions throughout the year.Traffic from other channels (bsearch, organic direct) also increased consistently but way behind gsearch.*/


 /*3. Yearly trend for Gsearch, but this time splitting out nonbrand and brand campaigns separately.
*/ 
SELECT 
    YEAR(ws.created_at) AS Year,
    COUNT(DISTINCT case when utm_campaign='nonbrand' then o.order_id else null end)
    /COUNT(DISTINCT  case when utm_campaign='nonbrand' then ws.website_session_id else null end)*100 as nonbrand_conv_rate,
    COUNT(DISTINCT case when utm_campaign='brand' then o.order_id else null end)
    /COUNT(DISTINCT  case when utm_campaign='brand' then ws.website_session_id else null end)*100 as brand_conv_rate
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON o.website_session_id = ws.website_session_id
WHERE
    YEAR(ws.created_at)!= '2015'
        AND ws.utm_source = 'gsearch'
GROUP BY 1 ;
# for gsearch, brand traffic converts at a higher rate(7.7% in 2014) than non-brand traffic(7.26% in 2014) over all the three years.

#Traffic Conversion Rates
#4. We need to check how much our traffic source, is generating sales and what is the session to order conversion rate.
SELECT 
	utm_source,
    utm_campaign,
    http_referer,
    COUNT(DISTINCT w.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT w.website_session_id)*100 AS session_to_order_conv_rate 
FROM
    website_sessions w
        LEFT JOIN
    orders o ON o.website_session_id = w.website_session_id
WHERE  YEAR(w.created_at)!= '2015'
GROUP BY 1,2,3
ORDER BY 4 DESC;
/*The conversion rate (CVR) is good for organic search and direct search at 8.6% and 7.02% respectively.
 Traffic from socialbook has a much lower CVR at 5.15%.Here we can bid down on socialbook.*/

/* BID OPTIMIZATION
Analyzing for bid optimization is about understanding the value of various 
segments of paid traffic, so that you can optimize your marketing budget
*/

# 5.Traffic conversion rate by device type.
SELECT 
    YEAR(ws.created_at) AS Year,
    COUNT(DISTINCT case when ws.device_type='desktop' then ws.website_session_id else null end) AS desktop_sessions,
    COUNT(DISTINCT case when ws.device_type='desktop'then o.order_id else null end) AS desktop_orders,
    COUNT(DISTINCT case when ws.device_type='mobile' then ws.website_session_id else null end) AS mobile_sessions,
    COUNT(DISTINCT case when ws.device_type='mobile'then o.order_id else null end) AS mobile_orders,
    COUNT(DISTINCT case when ws.device_type='desktop'then o.order_id else null end)
    /COUNT(DISTINCT case when ws.device_type='desktop' then ws.website_session_id else null end)*100 as desktop_conv_rate,
     COUNT(DISTINCT case when ws.device_type='mobile'then o.order_id else null end)
    /COUNT(DISTINCT case when ws.device_type='mobile' then ws.website_session_id else null end)*100 as mobile_conv_rate
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON o.website_session_id = ws.website_session_id
WHERE YEAR(ws.created_at)!= '2015'
GROUP BY 1 ;
# Conversion rate for desktop(9.18% in 2014) is way higher than mobile(3.3% in 2014).Based on this, it could be beneficial to increase bids for desktop users.


### ANALYZING WEBSITE PERFORMANCE

/*ANALYZING TOP WEBSITE CONTENT
Website content analysis is about understanding which pages are seen the 
most by your users, to identify where to focus on improving your business
• Finding the most-viewed pages that customers view on your site
• Identifying the most common entry pages to your website – the first thing a user sees
*/


# 6.Identifying top website pages
SELECT 
    pageview_url, COUNT(DISTINCT website_pageview_id) AS sessions
FROM
    website_pageviews
WHERE  YEAR(created_at)!= '2015'
GROUP BY 1
ORDER BY 2 DESC;
# The /products page is the most visited page on the website with 222,619 sessions, followed by /the-original-mr-fuzzy with 141,247 sessions,followed by /lander-2 and /home with 131,170 & 115,357 respectively.

# 7.Identifying top entry pages
WITH first_pageview AS(
SELECT 
    website_session_id, MIN(website_pageview_id) AS min_pv_id
FROM
    website_pageviews
GROUP BY website_session_id)

SELECT 
    wp.pageview_url AS landing_page,
    COUNT(distinct fp.website_session_id) AS sessions_hitting_this_lander
FROM
    first_pageview fp
        LEFT JOIN
    website_pageviews wp ON wp.website_pageview_id = fp.min_pv_id
WHERE  YEAR(wp.created_at)!= '2015'
GROUP BY wp.pageview_url
ORDER BY 2 DESC;
/* /lander-2 has the most sessions at 131,170 followed by /home at 115,357 sessions.
 This suggests that users are finding the /lander-2 page more engaging than other lander pages.*/
 
 /*LANDING PAGE PERFORMANCE & TESTING
Landing page analysis and testing is about understanding the performance of 
your key landing pages and then testing to improve your results
*/

#8. Calculating bounce rate
#BUSINESS CONTEXT :we want to see landing page performance 
SELECT b.pageview_url, 
COUNT(DISTINCT b.website_session_id) as sessions,
COUNT(DISTINCT CASE WHEN b.pageview_count=1 THEN b.website_session_id ELSE NULL END) as bounced_sessions,
COUNT(DISTINCT CASE WHEN b.pageview_count=1 THEN b.website_session_id ELSE NULL END)/COUNT(DISTINCT b.website_session_id) * 100 as bounce_percentage
FROM
(
SELECT  COUNT(DISTINCT website_pageview_id) as pageview_count, pageview_url,website_session_id,created_at
FROM website_pageviews
GROUP BY website_session_id) b 
WHERE  YEAR(b.created_at)!= '2015'
GROUP BY b.pageview_url
ORDER BY 4 DESC;
/* /lander-1 & /lander-4 has the highest bounce rate at 53.24% & 51.69%.While /lander-2 has 42.1% bounce rate.
 High bounce rates suggest visitors aren't finding what they expected or the pages aren't engaging enough. 
 This could be hurting conversions.*/
 
 
/*ANALYZING & TESTING CONVERSION FUNNELS
Conversion funnel analysis is about understanding and optimizing each step of 
your user’s experience on their journey toward purchasing your products
COMMON USE CASES:
• Identifying the most common paths customers take before purchasing your products
• Identifying how many of your users continue on to each next step in your conversion flow, 
and how many users abandon at each step
• Optimizing critical pain points where users are abandoning, so that you can convert more 
users and sell more products*/


/*9.Building Conversion Funnels
BUSINESS CONTEXT
 -we wan to build a mini conversion funnel, from /lander-2 to /cart
 -we want to know how many people reach each step, and also dropoff rates
 -we're looking at /lander-2 traffic only
 -we're looking at customers who like Mr Fuzzy only
 -we're looking at gsearch nonbrand sessions only
 -we're looking at  /billing-2 page only*/
SELECT
	 COUNT(DISTINCT ws.website_session_id) AS total_sessions
	,COUNT(CASE WHEN wpv.pageview_url = '/lander-2' THEN 1 ELSE NULL END)/COUNT(DISTINCT ws.website_session_id)*100 AS lander_2_ctr
    ,COUNT(CASE WHEN wpv.pageview_url = '/lander-2' THEN ws.website_session_id ELSE NULL END)/COUNT(CASE WHEN wpv.pageview_url = '/products' THEN ws.website_session_id ELSE NULL END)*100 AS lander_to_product_ctr
    ,COUNT(CASE WHEN wpv.pageview_url = '/the-original-mr-fuzzy' THEN ws.website_session_id ELSE NULL END)/COUNT(CASE WHEN wpv.pageview_url = '/products' THEN ws.website_session_id ELSE NULL END)*100 AS product_to_mrfuzzy_ctr
    ,COUNT(CASE WHEN wpv.pageview_url = '/cart' THEN ws.website_session_id ELSE NULL END)/COUNT(CASE WHEN wpv.pageview_url = '/the-original-mr-fuzzy' THEN ws.website_session_id ELSE NULL END)*100 AS mrfuzzy_to_cart_ctr
    ,COUNT(CASE WHEN wpv.pageview_url = '/shipping' THEN ws.website_session_id ELSE NULL END)/COUNT(CASE WHEN wpv.pageview_url = '/cart' THEN ws.website_session_id ELSE NULL END)*100 AS cart_to_shipping_ctr
    ,COUNT(CASE WHEN wpv.pageview_url ='/billing-2' THEN ws.website_session_id ELSE NULL END)/COUNT(CASE WHEN wpv.pageview_url = '/shipping' THEN ws.website_session_id ELSE NULL END)*100 AS shipping_to_billing_ctr
    ,COUNT(CASE WHEN wpv.pageview_url = '/thank-you-for-your-order' THEN ws.website_session_id ELSE NULL END)/COUNT(CASE WHEN wpv.pageview_url ='/billing-2' THEN ws.website_session_id ELSE NULL END)*100 AS billing_to_thankyou_ctr
FROM website_sessions AS ws
LEFT JOIN website_pageviews AS wpv
ON ws.website_session_id = wpv.website_session_id
AND utm_source = 'gsearch'
AND utm_campaign = 'nonbrand';
/*summary of the conversion funnel for users who liked Mr Fuzzy and came from non-branded Google Search traffic:

64.8% of users who visit the /lander-2 page continue to the products page.
62.5% of users who view the products page visit the Mr. Fuzzy page.
57.6% of users who view the Mr. Fuzzy page add it to the cart.
67.6% of users who made it to the cart proceed to shipping page.
73.8% of users proceed to billing pages.
67.2% of users successfully placed the order proceeding to thankyou page.
The conversion funnel shows a good initial interest in Mr. Fuzzy (high click-through rates from lander-2 to product and product to Mr. Fuzzy pages).
*/

###ANALYSIS FOR CHANNEL MANAGEMENT

/*  CHANNEL PORTFOLIO OPTIMIZATION
Analyzing a portfolio of marketing channels is about bidding efficiently and 
using data to maximize the effectiveness of your marketing budget
• Understanding which marketing channels are driving the most sessions and orders through 
your website
*/

# Comparing channel Characteristics
#10.Comparing channel characteristics of gsearch and bsearch brand and nonbrand campaign and the percentage of traffic coming from different devices.
SELECT 
    utm_source,
    utm_campaign,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN device_type = 'mobile' THEN website_session_id END) * 100 / COUNT(DISTINCT website_session_id) AS pct_mobile,
    COUNT(DISTINCT CASE WHEN device_type = 'desktop' THEN website_session_id END) * 100 / COUNT(DISTINCT website_session_id) AS pct_desktop
FROM
    website_sessions
WHERE
    utm_source IN ('gsearch' , 'bsearch')
        AND YEAR(created_at)!='2015'
GROUP BY 1,2;
/*GSearch drives most traffic (gsearch >> bsearch).
Non-brand campaigns dominate for both search engines.
Mobile traffic is significant but desktop still leads. Interestingly, bsearch has a higher desktop share than gsearch.
Consider prioritizing mobile optimization and investigate lower bsearch mobile traffic.*/


# Cross Channel Bid Optimization
#11. Nonbrand conversion rates from session to order for gsearch and bsearch, and slice them by device type.
SELECT 
    ws.device_type,
    ws.utm_source,
    #ws.utm_campaign,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    count(distinct o.order_id) as orders,
    count(distinct o.order_id)/COUNT(DISTINCT ws.website_session_id)*100 as conv_rate
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON ws.website_session_id = o.website_session_id
WHERE YEAR(ws.created_at)!='2015' AND ws.utm_campaign='nonbrand'
group by 1,2;
/*Here's a conclusion on non-brand conversion rates:

Desktop conversions are higher for both search engines (gsearch: 7.86%, bsearch: 7.32%).
Mobile conversions are lower (gsearch: 3.10%, bsearch: 3.09%).
Bid up both the channels gsearch and bsearch for desktop as they perform identically.
Focus on improving mobile user experience or investigate lower mobile conversion rates.*/


/*ANALYZING DIRECT TRAFFIC
Analyzing your branded or direct traffic is about keeping a pulse on how well 
your brand is doing with consumers, and how well your brand drives business
• Identifying how much revenue you are generating from direct traffic – this is high 
margin revenue without a direct cost of customer acquisition
• Understanding whether or not your paid traffic is generating a “halo” effect, and 
promoting additional direct traffic
• Assessing the impact of various initiatives on how many customers seek out your business*/

#12.Analyzing Direct traffic
SELECT 
    CASE 
		WHEN http_referer IS NULL THEN 'direct_type_in'
        WHEN http_referer='https://www.gsearch.com' and utm_source is null THEN 'gsearch_organic'
        WHEN http_referer='https://www.bsearch.com' and utm_source is null THEN 'bsearch_organic'
        ELSE 'others'
	END AS search_type,
    count(distinct website_session_id) as sessions
FROM
    website_sessions
    GROUP BY 1
    ORDER BY 2 DESC;
/* Direct traffic isn't the largest source (39,917 sessions).
"Others" category is largest (389,543 sessions), likely including paid marketing.
Paid traffic might still influence brand awareness even if users come directly later.*/


# Analyzing Free Channels
# 13. How the organic search ,direct type in and paid brand search are performing with respect to paid nonbrand search?
SELECT 
	year(created_at) as yr,
    COUNT(DISTINCT case when utm_campaign='nonbrand' then website_session_id end) AS nonbrand,
    COUNT(DISTINCT case when utm_campaign='brand' then website_session_id end) AS brand,
    COUNT(DISTINCT case when utm_campaign='brand' then website_session_id end)/
    COUNT(DISTINCT case when utm_campaign='nonbrand' then website_session_id end)*100 AS brand_pct_of_nonbrand,
    COUNT(DISTINCT  CASE WHEN http_referer IS NULL THEN website_session_id end) AS direct,
    COUNT(DISTINCT  CASE WHEN http_referer IS NULL THEN website_session_id end)/
    COUNT(DISTINCT case when utm_campaign='nonbrand' then website_session_id end)*100 AS direct_pct_of_nonbrand,
    COUNT(DISTINCT case when utm_source is null and http_referer is not null then website_session_id end) as organic,
    COUNT(DISTINCT case when utm_source is null and http_referer is not null then website_session_id end)/
    COUNT(DISTINCT case when utm_campaign='nonbrand' then website_session_id end)*100 as organic_pct_of_nonbrand
FROM
    website_sessions
WHERE YEAR(created_at)!='2015'
GROUP BY YEAR(created_at);
/*Paid non-brand drives the most traffic (highest nonbrand counts).
Organic search & direct traffic are similiar to paid brand search.
Focus on organic search optimization and brand building.
Analyze reasons behind lower conversion rate for paid brand search.*/



### BUSINESS PATTERNS & SEASONALITY

/* ANALYZING SEASONALITY & BUSINESS PATTERN
Analyzing business patterns is about generating insights to help you maximize 
efficiency and anticipate future trends
• Day-parting analysis to understand how much support staff you should have at different 
times of day or days of the week
• Analyzing seasonality to better prepare for upcoming spikes or slowdowns in demand
*/
 # 14.Analyzing seasonality by quarter
 SELECT
	YEAR(ws.created_at) AS yr,
    QUARTER(ws.created_at) AS qtr,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT ws.website_session_id)/COUNT(DISTINCT o.order_id) AS cvr
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON ws.website_session_id = o.website_session_id
WHERE YEAR(ws.created_at)!='2015'
GROUP BY 1,2;
/*Conversion rate (CVR) has decreased since launch(from 31.3 to 12.9), but sessions and orders have increased (2012-2014).
More users are coming to the site despite lower CVR.
Holiday season (4th quarter) sees a spike in sessions.
Investigate CVR decline and optimize marketing for peak seasons.
Focus on attracting more users while improving conversion efficiency.*/


# Analyzing Business Patterns
#15. Average website session volume , by hour of day and day week, to understand how much support staff is needed during different hours.
SELECT 
	hr,
    round(avg(website_session_id),1) as avg_sessions,
    round(avg(case when wkday=0 then website_session_id end),1) as mon,
    round(avg(case when wkday=1 then website_session_id end),1) as tue,
    round(avg(case when wkday=2 then website_session_id end),1) as wed,
    round(avg(case when wkday=3 then website_session_id end),1) as thu,
    round(avg(case when wkday=4 then website_session_id end),1) as fri,
    round(avg(case when wkday=5 then website_session_id end),1) as sat,
    round(avg(case when wkday=6 then website_session_id end),1) as sun
FROM
    (SELECT 
			date(created_at) as created_date,
            weekday(created_at) as wkday,
            hour(created_at) as hr,
            count(distinct website_session_id) as website_session_id
            from website_sessions
			where YEAR(created_at)!='2015'
			group by 1,2,3) as daily_hourly_sessions
GROUP BY 1
order by 1;
/*Weekday traffic peaks during business hours (8 AM - 5 PM), with a lunchtime rush (12 PM - 1 PM).
Weekends see lower traffic than weekdays.
Mondays have slightly lower traffic than other weekdays.
Fridays might have slightly higher traffic than other weekdays.
Allocate more support staff weekdays (especially lunchtime & business hours).*/




### PRODUCT ANALYSIS

/* PRODUCT SALES ANALYSIS
Analyzing product sales helps you understand how each product contributes to 
your business, and how product launches impact the overall portfolio
• Analyzing sales and revenue by product
• Monitoring the impact of adding a new product to your product portfolio
• Watching product sales trends to understand the overall health of your business
*/

#Product level sales analysis
# 16.show quarterly figures since the launch, for session-to-order conversion rate, revenue & margin per order, and revenue & margin per session. 
SELECT 
	YEAR(website_sessions.created_at) AS yr,
	QUARTER(website_sessions.created_at) AS qtr, 
	COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS session_to_order_conv_rate, 
    SUM(price_usd)/COUNT(DISTINCT orders.order_id) AS revenue_per_order, 
    SUM(price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session,
    SUM(price_usd-cogs_usd)/COUNT(DISTINCT orders.order_id) AS margin_per_order,
    SUM(price_usd-cogs_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS margin_per_session
FROM website_sessions 
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE YEAR(website_sessions.created_at)!='2015'
GROUP BY 1,2
ORDER BY 1,2;
/*Revenue, margin, and session-to-order conversion rate (conv_rate) have all increased consistently over the years (2012-2014).
Both higher conversion rate and more website traffic (sessions) contribute to revenue and margin growth.
The website shows strong performance with increasing customer acquisition and revenue generation.*/

/*PRODUCT LEVEL WEBSITE ANALYSIS
Product-focused website analysis is about learning how customers interact 
with each of your products, and how well each product converts customers
*/

# Product conversion Funnels
#17.Comparing conversion funnels from each product page to cart.
WITH products_sessions AS(
SELECT
    CASE WHEN pageview_url='/the-original-mr-fuzzy' THEN 'mrfuzzy'
    WHEN pageview_url='/the-forever-love-bear' THEN 'lovebear'
    WHEN pageview_url='/the-birthday-sugar-panda' THEN 'sugarpanda'
    WHEN pageview_url='/the-hudson-river-mini-bear' THEN 'minibear'
    ELSE 'error' END AS product_seen,
    website_session_id, website_pageview_id
FROM website_pageviews
WHERE pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear','/the-birthday-sugar-panda','/the-hudson-river-mini-bear')
AND YEAR(created_at)!='2015')

SELECT product_seen,
sessions,
to_cart/sessions AS product_page_click_rt,
    to_shipping/to_cart AS cart_click_rt,
    to_billing/to_shipping AS shipping_click_rt,
    to_thankyou/to_billing AS billing_click_rt
FROM
(SELECT product_seen,
COUNT(DISTINCT ps.website_session_id) AS sessions,
COUNT(CASE WHEN wp.pageview_url='/cart' THEN '1' ELSE NULL END) AS to_cart,
COUNT(CASE WHEN wp.pageview_url='/shipping' THEN '1' ELSE NULL END) AS to_shipping,
    COUNT(CASE WHEN wp.pageview_url='/billing-2' THEN '1' ELSE NULL END) AS to_billing,
    COUNT(CASE WHEN wp.pageview_url='/thank-you-for-your-order' THEN '1' ELSE NULL END) AS to_thankyou
FROM products_sessions ps
LEFT JOIN website_pageviews wp
ON ps.website_session_id = wp.website_session_id
        AND wp.website_pageview_id >= ps.website_pageview_id
GROUP BY 1) AS funnel_sessions
ORDER BY 2 DESC;

/*Mr. Fuzzy has the highest brand awareness (sessions) but lower click-through rates in the funnel.
Love Bear has strong click-through rates throughout the funnel, suggesting a well-optimized experience.
Sugar Panda shows good click-through rates similar to Love Bear.
Mini Bear has lower click-through rates, indicating room for funnel optimization.
Analyze user behavior and optimize the funnel for each product to improve conversion rates.*/


/* PRODUCT REFUND ANALYSIS
Analyzing product refund rates is about controlling for quality and 
understanding where you might have problems to address
*/

# 18.Product Refund Rates

SELECT 
    YEAR(oi.created_at) AS yr, 
    QUARTER(oi.created_at) AS qtr,
    COUNT(DISTINCT CASE WHEN product_id=1 THEN oi.order_item_id ELSE NULL END) AS p1_orders,
    COUNT(DISTINCT CASE WHEN product_id=1 THEN oir.order_item_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN product_id=1 THEN oi.order_item_id ELSE NULL END)*100 AS p1_refund_rt,
    COUNT(DISTINCT CASE WHEN product_id=2 THEN oi.order_item_id ELSE NULL END) AS p2_orders,
    COUNT(DISTINCT CASE WHEN product_id=2 THEN oir.order_item_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN product_id=2 THEN oi.order_item_id ELSE NULL END)*100 AS p2_refund_rt,
    COUNT(DISTINCT CASE WHEN product_id=3 THEN oi.order_item_id ELSE NULL END) AS p3_orders,
    COUNT(DISTINCT CASE WHEN product_id=3 THEN oir.order_item_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN product_id=3 THEN oi.order_item_id ELSE NULL END)*100 AS p3_refund_rt,
    COUNT(DISTINCT CASE WHEN product_id=4 THEN oi.order_item_id ELSE NULL END) AS p4_orders,
    COUNT(DISTINCT CASE WHEN product_id=4 THEN oir.order_item_id ELSE NULL END)/
    COUNT(DISTINCT CASE WHEN product_id=4 THEN oi.order_item_id ELSE NULL END)*100 AS p4_refund_rt
FROM
    order_items oi
        LEFT JOIN
    order_item_refunds oir ON oir.order_item_id = oi.order_item_id
WHERE YEAR(oi.created_at)!='2015'
GROUP BY 1,2;
/*Product 1: Highest refund rate, especially in Q3 of 2012 and 2014. Investigate customer reviews and product changes for those quarters.
Product 2: Consistently low refund rates, indicating good performance.
Product 3: High refund rates initially, but decreasing over time. Possible improvements made to the product or customer service.
Product 4: Low refund rates, similar to Product 2.
Analyze customer feedback, product changes, and marketing campaigns to understand refund rate drivers and take targeted actions
 to potentially reduce them, especially for Product 1. This can improve customer satisfaction and potentially increase revenue.*/

### USER ANALYSIS

/*ANALYZE REPEAT BEHAVIOR
Analyzing repeat visits helps you understand user behavior and identify 
some of your most valuable customers
• Analyzing repeat activity to see how often customers are coming back to visit your site
• Understanding which channels they use when they come back, and whether or not you are 
paying for them again through paid channels
*/


# 19.Identifying repeat Visitors
SELECT 
		repeats,
    COUNT(DISTINCT user_id) AS users
FROM
    (SELECT 
        user_id,
        sum(is_repeat_session) as repeats
    FROM
        website_sessions
    WHERE YEAR(created_at)!='2015'
    GROUP BY 1
    HAVING MIN(is_repeat_session) = 0
    ) AS repeat_session
GROUP BY 1
ORDER BY 1;
/*"repeats = 0" represents new visitors, with a significantly higher number compared to repeat visitors.
 There are also significantly fewer visitors on their third visit ("repeats = 2") compared to both second-time visitors and potentially even fourth-time visitors ("repeats = 3").
 This data suggests a need to focus on strategies to convert new visitors into repeat customers, with particular attention to keeping users engaged after their second visit.*/
 
 
# Analyzing Repeat Behavior
/*20.TO understand the behaviour of these repeat customers, lets check the minimum, the maximum and average time begtween the first and the second session
for customers who do come back.*/
with user_next_session_date as(
SELECT user_id,website_session_id,
    is_repeat_session,
    created_at,
    lead(created_at) over(partition by user_id order by website_session_id) as next_session_date
FROM
    website_sessions
where YEAR(created_at)!='2015')

select 
	avg(datediff(next_session_date,created_at)) as avg_diff,
    min(datediff(next_session_date,created_at)) as min_diff,
    max(datediff(next_session_date,created_at)) as max_diff
	from user_next_session_date
    where is_repeat_session=0
    and next_session_date is not null;
    /*Some users revisit almost immediately next day.
On average, repeat visitors return after about a month (avg 33.82 days).
The maximum time between first and second visit is 69 days.
Analyze user behavior and segment repeat visitors to understand their browsing patterns and tailor strategies to keep them engaged and potentially increase customer loyalty and revenue.*/


# 21.Analyzing Repeat Channel Behavior to find out the channels our repeat visitors come back through.
SELECT 
    case 
		when utm_source is null and http_referer in ('https://www.gsearch.com','https://www.bsearch.com') then 'organic_search'
        when utm_campaign='nonbrand' then 'paid_nonbrand'
        when utm_campaign='brand' then 'paid_brand'
        when utm_source is null and http_referer is null then 'direct_type_in'
        when utm_source ='socialbook' then 'paid_social'
	end as channel_group,
    count(case when is_repeat_session=0 then website_session_id end) as new_sessions,
    count(case when is_repeat_session=1 then website_session_id end) as repeat_sessions
FROM
    website_sessions
    where YEAR(created_at)!='2015'
    group by 1
    order by 3 desc;
    /*Organic search is the top channel for repeat visitors, followed by paid brand and direct type-in.
Paid non-brand and paid social have lower repeat session counts compared to others.
This suggests users from organic search, brand awareness, or direct visits are more likely to return.*/


# New vs. Repeat performance
#22.Lets compare the conversion rates and revenue per session for repeat sessions vs new sessions.
SELECT 
    is_repeat_session,
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT order_id)/COUNT(DISTINCT ws.website_session_id) AS conv_rate,
    SUM(price_usd)/COUNT(DISTINCT ws.website_session_id) AS revenue_per_session
FROM
    website_sessions ws
        LEFT JOIN
    orders o ON ws.website_session_id = o.website_session_id
WHERE
    YEAR(ws.created_at)!='2015'
GROUP BY 1;
/*Repeat visitors (is_repeat_session = 1) have higher conversion rates (conv_rate) and revenue per session compared to new visitors.
This suggests repeat visitors are more likely to buy and spend more per purchase.
Possible reasons include brand familiarity, higher engagement, and trust built from past experiences.*/

#23. Let's check the customer lifetime value(CLTV)
WITH  AOV AS(
SELECT 
    user_id,(items_purchased * price_usd*COUNT(*)) AS AOVPurchase_frequency
FROM
    orders
GROUP BY 1),    
customer_lifespan AS
(SELECT 
	user_id,AVG(datediff(next_session_date,created_at)) as avg_diff
FROM
(
SELECT user_id,website_session_id,
    is_repeat_session,
    created_at,
    lead(created_at) over(partition by user_id order by website_session_id) as next_session_date
FROM
    website_sessions
where YEAR(created_at)!='2015') as user_next_session_date
 where is_repeat_session=0
    and next_session_date is not null
GROUP BY 1),
CLTV AS
(SELECT a.user_id,AOVPurchase_frequency*avg_diff AS CLTV_per_user
FROM customer_lifespan cl
JOIN AOV a  ON a.user_id=cl.user_id )

SELECT AVG(CLTV_per_user)/2 AS Avg_CLTV
FROM CLTV;
/*average CLTV of USD 1433.91 per year per user indicates that customers who purchase from us tend to generate 
significant revenue over time, reflecting strong customer relationships and the potential for recurring revenue.*/
