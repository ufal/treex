#!/usr/bin/env perl

use strict;
use warnings;
use Parse::RecDescent;
my $grammar = q{
        startrule:  SCEN EOF                            {$return = ($item[1])}
        SCEN:       LINE                                {$return = ($item[1])}
        SCEN:       LINE SCEN                           {$return = ($item[1],$item[2])}
        LINE:       BLOCK COMMENT | BLOCK               {$return = ($item[1])}
        EOF:        /^\Z/
        BLOCK:      TBNAME PARAMS                        {$return = {
                                                            block_name=>$item[1],
                                                            block_parameters=>$item[2],
                                                            }
                                                        }
        BLOCK:      TBNAME                               {$return = {
                                                            block_name=>$item[1],
                                                            block_parameters=>[],
                                                            }
                                                        }
        BLOCK:      INCLUDE                             {$return = 'TODO'}
        INCLUDE:    /\w+\.scen/
        TBNAME:     BNAME                               {$return = "Treex::Block::$item[1]"}
        BNAME:      /\w+::/ BNAME                       {$return = $item[1].$item[3]}
        BNAME:      /\w+/                               {$return = $item[1]}
        PARAMS:     PARAM                               {$return = ($item[1])}
        PARAMS:     PARAM PARAMS                        {$return = ($item[1],$item[2])}
        PARAM:      PNAME '=' PVALUE                    {$return = $item[1]}
        PNAME:      /\w+/                               {$return = $item[1]}
        PVALUE:     q(') PSQUOTE q(')                   {$return = $item[2]}
        PVALUE:     q(") PDQUOTE q(")                   {$return = $item[2]}
        PVALUE:     '`' PTICKED '`'                     {$return = $item[1].$item[2].$item[3]}
        PVALUE:     PNOTQUOTED                          {$return = $item[1]}
        PSQUOTE:    /[^']+/                             {$return = $item[1]}
        PDQUOTE:    /[^"]+/                             {$return = $item[1]}
        PNOTQUOTED: /\S+/                               {$return = $item[1]}
        PTICKED:    /[^`]+/                             {$return = $item[1]}
        COMMENT:    /#.*\n/
    };
Parse::RecDescent->Precompile( $grammar, 'Treex::Core::ScenarioParser' );
