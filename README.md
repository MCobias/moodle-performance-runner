Moodle performance toolkit
==========================
Moodle performance toolkit is a tool for moodle performance analysis. It provide tools to achieve objective:
  - Generate site with specified number of
    - Categories
    - Courses
    - Activities and resources
    - Users
  - Create JMeter plan (JMX) from behat scenario
  - Run JMeter plan and log information
  - Compare run data
## Requirements:
* MySQL or PostgresSQL or Mariadb or MSSQL or oracle
* git
* curl
* PHP 5.4.4+
* Java 6 or later
* Jmeter: https://jmeter.apache.org/download_jmeter.cgi binaries (probably you will face problems using apt-get or other package management systems to download it)
* Browsermob proxy: http://bmp.lightbody.net/

## Generate test site:
Tool supports 5 sizes, according to specified size appropriate data will be generated.
* [xs] - Extra small
* [s] - Small
* [m] - Medium
* [l] - Large
* [xl] - Extra large

This tool comes with following templates, but you can add your own behat feature template.
* categories - Create caretories and sub-catgories.
* courses - Create courses in each category and sub-category
* activities - Create all core activities in each course
* users - Create users and enrol them as students/teachers/managers/course creators in each course.

```sh
vendor/bin/moodle-performance-site --install --testdata=s
```
> If you already have a site installed, then it will generate data depending on template chosen provided --force option is passed.

> Before you use this tool, config.php should be set manually by you with min. config values like dataroot, wwwroot, db etc.
In addition to this, you should set **$CFG->performance_dataroot** to a directory where performance data will be be saved.

## Save site state
Often we need to backup and restore site state after and before data is generated. This can be done by
```sh
vendor/bin/moodle-performance-site --backup="StateName"
vendor/bin/moodle-performance-site --restore="StateName"
```
Above commands will backup dataroot directory and database state and will restore the same from the backedup state.

## Define oder in which data is generated (sitegenerator.json)
Site data use behat feature and steps to generate data and it's order is defined by sitegenerator.json-dist
```
vendor/moodlehq/performance-toolkit/sitegenerator/sitegenerator.json-dist
```
Order in which fetaures are defined in json file will be respected. You should only pass custom values which are needed with respect to site size. Rest should be handled by feature and custom steps.
```
{
  "categories": {
    "scenario": {
      "catinstances": {"xs": 1, "s": 10, "m": 100, "l": 10000, "xl": 100000},
      "subcatinstances": {"xs": 1, "s": 10, "m": 100, "l": 1000, "xl": 10000},
      "maxcategory": ["categories","scenario","catinstances"] // Reference 
    }
  }
}
```
If you are using scenario outline, then passing count and reference will update your feature file with Example. In the following code Example will be added to your feature file for the specified count, replacing <catname> and <catnewname> values with the specified values.
```
{
  "categories": {
    "scenario": {
      "catinstances": {"xs": 1, "s": 10, "m": 100, "l": 10000, "xl": 100000},
      "subcatinstances": {"xs": 1, "s": 10, "m": 100, "l": 1000, "xl": 10000},
      "maxcategory": ["categories","scenario","catinstances"] // Reference 
    },
    "scenario-ouline": {
      "count": {"xs": 1, "s": 10, "m": 100, "l": 10000, "xl": 100000},
      "catname": "TC#count#",
      "catnewname": "Test Course #count#"
    }
  }
}
```

#### Default feature are placed in
```
vendor/moodlehq/performance-toolkit/fixtures
```
#### Default behat Classes are placed in
Moodle naming convention is observered while naming these classes. File name should be behat_CLASSNAME.php
```
vendor/moodlehq/performance-toolkit/classes
```

### Adding custom feature and steps.
* Create $CFG->dirroot/sitegenerator.json
* Add contextpath and featurepath for every generator set.
```
"categories": {
    "featurepath": "ABSOLUTE_PATH_TO_FEATURE",
    "contextpath": "ABSOLUTE_PATH_TO_CONTEXT_FILE", // This can be an array or string.
    "scenario": {
      "catinstances": {"xs": 1, "s": 10, "m": 100, "l": 10000, "xl": 100000},
      "subcatinstances": {"xs": 1, "s": 10, "m": 100, "l": 1000, "xl": 10000},
      "maxcategory": ["categories","scenario","catinstances"]
    }
  },
```

# Create JMeter test plan:
  ## Start BrowserMObProxy
Download latest version of the BrowserMob Proxy & Start it. This is used for capturing http requests and allowing user to select which http request user wants to include in test plan, with which params.
```sh
$ cd browsermob-proxy-xx/bin
$ ./browsermob-proxy -port 9090
```
## Background
Testplan is composed of series of http requests. When run by JMeter, sampler parse http response and extract performance
data (in moodle footer). To execute a test plan we have to define how many users will execute http request and how many times it needs to be executed. This tool provie easy interface to write a feature file and allow user to select http request which they are interested in. Important thing tonote here is: The query params should be hard-coded only if they remain same for each user like courseid. But id's like forum post should be extracted from page on run time and then used. To start creating existing testplan run:
```
vendor/bin/vendor/bin/moodle_behat_2jmx -t=s --proxyurl=localhost:9090
```
If you are creating new plan then you should run behat command requested by the above command.

#### Test plan comprise of number of threads (users) who will login and consecutive requests will be executed as that user for that thread. This can be done by
   ```
   Given I login as any "student" enrolled in course "TC"
   And I capture "login" http requests
   ```
   This will create students{featurefilename).csv file and a variable ${student} should be substituted for userid query in http request.
 ####
