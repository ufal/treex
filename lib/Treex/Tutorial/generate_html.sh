#!/bin/bash
perl -MPod::Simple::HTML -e Pod::Simple::HTML::go Install.pod\
 | perl -nlpe 's{</head>}{<link rel="stylesheet" title="treexpod" type="text/css" href="treexpod.css" media="all" ></head>}'\
 > install.html

perl -MPod::Simple::HTML -e Pod::Simple::HTML::go FirstSteps.pod\
 | perl -nlpe 's{</head>}{<link rel="stylesheet" title="treexpod" type="text/css" href="treexpod.css" media="all" ></head>}'\
 > firststeps.html
