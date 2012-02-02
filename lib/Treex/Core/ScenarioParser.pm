package Treex::Core::ScenarioParser;
use Parse::RecDescent;

{ my $ERRORS;


package Parse::RecDescent::Treex::Core::ScenarioParser;
use strict;
use vars qw($skip $AUTOLOAD  );
@Parse::RecDescent::Treex::Core::ScenarioParser::ISA = ();
$skip = '\s*';

use File::Slurp;
use File::Basename;
## no critic (Miscellanea::ProhibitUnrestrictedNoCritic)
## no critic Generated code follows
no warnings;
;


{
local $SIG{__WARN__} = sub {0};
# PRETEND TO BE IN Parse::RecDescent NAMESPACE
*Parse::RecDescent::Treex::Core::ScenarioParser::AUTOLOAD   = sub
{
    no strict 'refs';
    $AUTOLOAD =~ s/^Parse::RecDescent::Treex::Core::ScenarioParser/Parse::RecDescent/;
    goto &{$AUTOLOAD};
}
}

push @Parse::RecDescent::Treex::Core::ScenarioParser::ISA, 'Parse::RecDescent';
# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::SPACE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SPACE"};

    Parse::RecDescent::_trace(q{Trying rule: [SPACE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{SPACE},
                  $tracelevel)
                    if defined $::RD_TRACE;


    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/\\s+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\s+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SPACE});
        %item = (__RULE__ => q{SPACE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\s+/]}, Parse::RecDescent::_tracefirst($text),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\s+)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/\\s+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{SPACE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SPACE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{SPACE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::EMPTY
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"EMPTY"};
    
    Parse::RecDescent::_trace(q{Trying rule: [EMPTY]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{EMPTY},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{//});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [//]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{EMPTY});
        %item = (__RULE__ => q{EMPTY});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [//]}, Parse::RecDescent::_tracefirst($text),
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        


        Parse::RecDescent::_trace(q{>>Matched production: [//]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{EMPTY},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{EMPTY},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{EMPTY},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PNOTQUOTED
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PNOTQUOTED"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PNOTQUOTED]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PNOTQUOTED},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/\\S+/, or EMPTY});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\S+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PNOTQUOTED});
        %item = (__RULE__ => q{PNOTQUOTED});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\S+/]}, Parse::RecDescent::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\S+)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/\\S+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [EMPTY]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PNOTQUOTED});
        %item = (__RULE__ => q{PNOTQUOTED});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [EMPTY]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PNOTQUOTED},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::EMPTY($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [EMPTY]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PNOTQUOTED},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [EMPTY]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{EMPTY}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = ''};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [EMPTY]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PNOTQUOTED},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PNOTQUOTED},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PNOTQUOTED},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::SLASHEDSQUOTE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SLASHEDSQUOTE"};
    
    Parse::RecDescent::_trace(q{Trying rule: [SLASHEDSQUOTE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{SLASHEDSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/\\\\'/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\\\'/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SLASHEDSQUOTE});
        %item = (__RULE__ => q{SLASHEDSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\\\'/]}, Parse::RecDescent::_tracefirst($text),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\\')/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = "'"};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/\\\\'/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{SLASHEDSQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SLASHEDSQUOTE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{SLASHEDSQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::COMMENT
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"COMMENT"};
    
    Parse::RecDescent::_trace(q{Trying rule: [COMMENT]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{COMMENT},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/#[^\\n]*/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/#[^\\n]*/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{COMMENT});
        %item = (__RULE__ => q{COMMENT});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/#[^\\n]*/]}, Parse::RecDescent::_tracefirst($text),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:#[^\n]*)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = ''};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/#[^\\n]*/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{COMMENT},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{COMMENT},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{COMMENT},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::EOF
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"EOF"};
    
    Parse::RecDescent::_trace(q{Trying rule: [EOF]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{EOF},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/^\\Z/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/^\\Z/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{EOF});
        %item = (__RULE__ => q{EOF});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/^\\Z/]}, Parse::RecDescent::_tracefirst($text),
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:^\Z)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/^\\Z/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{EOF},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{EOF},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{EOF},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::NOTSQUOTE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"NOTSQUOTE"};
    
    Parse::RecDescent::_trace(q{Trying rule: [NOTSQUOTE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{NOTSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/[^']*[^'\\\\]/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[^']*[^'\\\\]/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{NOTSQUOTE});
        %item = (__RULE__ => q{NOTSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[^']*[^'\\\\]/]}, Parse::RecDescent::_tracefirst($text),
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^']*[^'\\])/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[^']*[^'\\\\]/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{NOTSQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{NOTSQUOTE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{NOTSQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::TBNAME
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"TBNAME"};
    
    Parse::RecDescent::_trace(q{Trying rule: [TBNAME]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{TBNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/::/, or BNAME});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/::/ BNAME]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{TBNAME});
        %item = (__RULE__ => q{TBNAME});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/::/]}, Parse::RecDescent::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:::)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying subrule: [BNAME]},
                  Parse::RecDescent::_tracefirst($text),
                  q{TBNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{BNAME})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::BNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [BNAME]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{TBNAME},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [BNAME]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{BNAME}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/::/ BNAME]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [BNAME]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{TBNAME});
        %item = (__RULE__ => q{TBNAME});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [BNAME]},
                  Parse::RecDescent::_tracefirst($text),
                  q{TBNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::BNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [BNAME]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{TBNAME},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [BNAME]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = "Treex::Block::$item{BNAME}"};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [BNAME]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{TBNAME},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{TBNAME},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{TBNAME},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::startrule
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"startrule"};
    
    Parse::RecDescent::_trace(q{Trying rule: [startrule]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{startrule},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{SCEN});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [SCEN EOF]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{startrule});
        %item = (__RULE__ => q{startrule});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [SCEN]},
                  Parse::RecDescent::_tracefirst($text),
                  q{startrule},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::SCEN($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [SCEN]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{startrule},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [SCEN]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SCEN}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying subrule: [EOF]},
                  Parse::RecDescent::_tracefirst($text),
                  q{startrule},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{EOF})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::EOF($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [EOF]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{startrule},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [EOF]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{EOF}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{SCEN}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [SCEN EOF]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{startrule},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{startrule},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{startrule},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::LINE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"LINE"};
    
    Parse::RecDescent::_trace(q{Trying rule: [LINE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{BLOCK, or COMMENT});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [BLOCK COMMENT]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{LINE});
        %item = (__RULE__ => q{LINE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [BLOCK]},
                  Parse::RecDescent::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::BLOCK($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [BLOCK]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [BLOCK]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BLOCK}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying subrule: [COMMENT]},
                  Parse::RecDescent::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{COMMENT})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::COMMENT($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [COMMENT]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [COMMENT]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{COMMENT}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{BLOCK}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [BLOCK COMMENT]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [BLOCK]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{LINE});
        %item = (__RULE__ => q{LINE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [BLOCK]},
                  Parse::RecDescent::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::BLOCK($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [BLOCK]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [BLOCK]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BLOCK}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{BLOCK}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [BLOCK]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [COMMENT]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{LINE});
        %item = (__RULE__ => q{LINE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [COMMENT]},
                  Parse::RecDescent::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::COMMENT($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [COMMENT]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [COMMENT]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{COMMENT}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = []};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [COMMENT]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{LINE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{LINE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{LINE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::BLOCK
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"BLOCK"};
    
    Parse::RecDescent::_trace(q{Trying rule: [BLOCK]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{INCLUDE, or TBNAME});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [INCLUDE]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [INCLUDE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::INCLUDE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [INCLUDE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [INCLUDE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{INCLUDE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {
                                                    my $included = read_file( $item{INCLUDE} );
                                                    my $result = $thisparser->startrule( $included, 1, $item{INCLUDE} );
                                                    if (defined $result and ref $result eq 'ARRAY') {
                                                        $return = [@$result];
                                                    } else {
                                                        $return = undef;
                                                    }
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [INCLUDE]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [TBNAME PARAMS]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [TBNAME]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::TBNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [TBNAME]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [TBNAME]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{TBNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying subrule: [PARAMS]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PARAMS})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PARAMS($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PARAMS]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PARAMS]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAMS}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [{
                                                        block_name=>$item{TBNAME},
                                                        block_parameters=>$item{PARAMS},
                                                    }]
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [TBNAME PARAMS]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [TBNAME]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [TBNAME]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::TBNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [TBNAME]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [TBNAME]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{TBNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [{
                                                        block_name=>$item{TBNAME},
                                                        block_parameters=>[],
                                                    }]
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [TBNAME]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{BLOCK},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{BLOCK},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{BLOCK},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PNAME
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PNAME"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PNAME]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/\\w+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\w+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PNAME});
        %item = (__RULE__ => q{PNAME});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\w+/]}, Parse::RecDescent::_tracefirst($text),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\w+)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/\\w+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PNAME},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PNAME},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PNAME},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PTICKED
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PTICKED"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PTICKED]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PTICKED},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/[^`]+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[^`]+/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PTICKED});
        %item = (__RULE__ => q{PTICKED});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[^`]+/]}, Parse::RecDescent::_tracefirst($text),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^`]+)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[^`]+/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PTICKED},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PTICKED},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PTICKED},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::BNAME
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"BNAME"};
    
    Parse::RecDescent::_trace(q{Trying rule: [BNAME]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{BNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/[A-Z]\\w*::/, or /[A-Z]\\w*/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[A-Z]\\w*::/ BNAME]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{BNAME});
        %item = (__RULE__ => q{BNAME});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[A-Z]\\w*::/]}, Parse::RecDescent::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[A-Z]\w*::)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying subrule: [BNAME]},
                  Parse::RecDescent::_tracefirst($text),
                  q{BNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{BNAME})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::BNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [BNAME]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{BNAME},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [BNAME]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1].$item[2]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[A-Z]\\w*::/ BNAME]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[A-Z]\\w*/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{BNAME});
        %item = (__RULE__ => q{BNAME});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[A-Z]\\w*/]}, Parse::RecDescent::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[A-Z]\w*)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[A-Z]\\w*/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{BNAME},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{BNAME},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{BNAME},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::SCEN
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SCEN"};
    
    Parse::RecDescent::_trace(q{Trying rule: [SCEN]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{SCEN},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{LINE});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [LINE SCEN]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SCEN});
        %item = (__RULE__ => q{SCEN});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [LINE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{SCEN},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::LINE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [LINE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{SCEN},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [LINE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{LINE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying subrule: [SCEN]},
                  Parse::RecDescent::_tracefirst($text),
                  q{SCEN},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{SCEN})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::SCEN($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [SCEN]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{SCEN},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [SCEN]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SCEN}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{LINE}},@{$item{SCEN}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [LINE SCEN]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [LINE]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{SCEN});
        %item = (__RULE__ => q{SCEN});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [LINE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{SCEN},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::LINE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [LINE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{SCEN},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [LINE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{LINE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{LINE}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [LINE]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{SCEN},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SCEN},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{SCEN},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::INCLUDE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"INCLUDE"};
    
    Parse::RecDescent::_trace(q{Trying rule: [INCLUDE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{INCLUDE},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/\\/\\S+\\.scen/, or /[^\\/#]\\S+\\.scen/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/\\/\\S+\\.scen/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{INCLUDE});
        %item = (__RULE__ => q{INCLUDE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/\\/\\S+\\.scen/]}, Parse::RecDescent::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\/\S+\.scen)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/\\/\\S+\\.scen/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[^\\/#]\\S+\\.scen/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{INCLUDE});
        %item = (__RULE__ => q{INCLUDE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[^\\/#]\\S+\\.scen/]}, Parse::RecDescent::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^\/#]\S+\.scen)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {   my $from_file = $arg[0];
                                                    if ($from_file =~ /./) {
                                                        $return = dirname($from_file) . "/$item[1]";
                                                    } else {
                                                        $return = "./$item[1]";
                                                    }
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[^\\/#]\\S+\\.scen/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{INCLUDE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{INCLUDE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{INCLUDE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PDQUOTE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PDQUOTE"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PDQUOTE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PDQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/[^"]*/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/[^"]*/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PDQUOTE});
        %item = (__RULE__ => q{PDQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/[^"]*/]}, Parse::RecDescent::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^"]*)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/[^"]*/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PDQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PDQUOTE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PDQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PSQUOTE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PSQUOTE"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PSQUOTE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{NOTSQUOTE});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [NOTSQUOTE SLASHEDSQUOTE PSQUOTE]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PSQUOTE});
        %item = (__RULE__ => q{PSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [NOTSQUOTE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::NOTSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [NOTSQUOTE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [NOTSQUOTE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{NOTSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying subrule: [SLASHEDSQUOTE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{SLASHEDSQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::SLASHEDSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [SLASHEDSQUOTE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [SLASHEDSQUOTE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SLASHEDSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying subrule: [PSQUOTE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PSQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PSQUOTE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PSQUOTE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{NOTSQUOTE}.$item{SLASHEDSQUOTE}.$item{PSQUOTE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [NOTSQUOTE SLASHEDSQUOTE PSQUOTE]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [NOTSQUOTE]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PSQUOTE});
        %item = (__RULE__ => q{PSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [NOTSQUOTE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::NOTSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [NOTSQUOTE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [NOTSQUOTE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{NOTSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }


        Parse::RecDescent::_trace(q{>>Matched production: [NOTSQUOTE]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PSQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PSQUOTE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PSQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PARAMS
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PARAMS"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PARAMS]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PARAMS},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{PARAM});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [PARAM PARAMS]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PARAMS});
        %item = (__RULE__ => q{PARAMS});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [PARAM]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PARAMS},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PARAM($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PARAM]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PARAMS},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PARAM]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAM}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying subrule: [PARAMS]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PARAMS},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PARAMS})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PARAMS($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PARAMS]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PARAMS},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PARAMS]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAMS}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [$item{PARAM}, @{$item{PARAMS}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [PARAM PARAMS]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [PARAM]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PARAMS});
        %item = (__RULE__ => q{PARAMS});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [PARAM]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PARAMS},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PARAM($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PARAM]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PARAMS},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PARAM]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAM}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [$item{PARAM}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [PARAM]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PARAMS},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PARAMS},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PARAMS},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PARAM
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PARAM"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PARAM]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PARAM},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{PNAME});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        local $skip = defined($skip) ? $skip : $Parse::RecDescent::skip;
        Parse::RecDescent::_trace(q{Trying production: [PNAME '=' <skip: qr//> PVALUE]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PARAM});
        %item = (__RULE__ => q{PARAM});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [PNAME]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PARAM},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PNAME]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PARAM},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PNAME]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: ['=']},
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{'='})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A\=/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(qq{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{__STRING1__}=$current_match;
        

        

        Parse::RecDescent::_trace(q{Trying directive: [<skip: qr//>]},
                    Parse::RecDescent::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE; 
        $_tok = do { my $oldskip = $skip; $skip= qr//; $oldskip };
        if (defined($_tok))
        {
            Parse::RecDescent::_trace(q{>>Matched directive<< (return value: [}
                        . $_tok . q{])},
                        Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        else
        {
            Parse::RecDescent::_trace(q{<<Didn't match directive>>},
                        Parse::RecDescent::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        
        last unless defined $_tok;
        push @item, $item{__DIRECTIVE1__}=$_tok;
        

        Parse::RecDescent::_trace(q{Trying subrule: [PVALUE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PARAM},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PVALUE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PVALUE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PVALUE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PARAM},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PVALUE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PVALUE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PNAME}.'='.$item{PVALUE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [PNAME '=' <skip: qr//> PVALUE]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PARAM},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PARAM},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PARAM},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args)
sub Parse::RecDescent::Treex::Core::ScenarioParser::PVALUE
{
	my $thisparser = $_[0];
	use vars q{$tracelevel};
	local $tracelevel = ($tracelevel||0)+1;
	$ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PVALUE"};
    
    Parse::RecDescent::_trace(q{Trying rule: [PVALUE]},
                  Parse::RecDescent::_tracefirst($_[1]),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;

    
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  defined($_[2]) && $_[2];
    my $_noactions = defined($_[3]) && $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep="";
    my $current_match;
    my $expectation = new Parse::RecDescent::Expectation(q{/'/, or /"/, or /`/, or PNOTQUOTED});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/'/ PSQUOTE /'/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/'/]}, Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:')/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying subrule: [PSQUOTE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PSQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PSQUOTE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PSQUOTE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: [/'/]}, Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{/'/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:')/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN2__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PSQUOTE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/'/ PSQUOTE /'/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/"/ PDQUOTE /"/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/"/]}, Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:")/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying subrule: [PDQUOTE]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PDQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PDQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PDQUOTE]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PDQUOTE]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PDQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: [/"/]}, Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{/"/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:")/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN2__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PDQUOTE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/"/ PDQUOTE /"/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [/`/ PTICKED /`/]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying terminal: [/`/]}, Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:`)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying subrule: [PTICKED]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PTICKED})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PTICKED($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PTICKED]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PTICKED]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PTICKED}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying terminal: [/`/]}, Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $lastsep = "";
        $expectation->is(q{/`/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:`)/)
        {
            
            $expectation->failed();
            Parse::RecDescent::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
		$current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN2__}=$current_match;
        

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1].$item[2].$item[3]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [/`/ PTICKED /`/]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_trace(q{Trying production: [PNOTQUOTED]},
                      Parse::RecDescent::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[3];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_trace(q{Trying subrule: [PNOTQUOTED]},
                  Parse::RecDescent::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::Treex::Core::ScenarioParser::PNOTQUOTED($thisparser,$text,$repeating,$_noactions,sub { \@arg })))
        {
            
            Parse::RecDescent::_trace(q{<<Didn't match subrule: [PNOTQUOTED]>>},
                          Parse::RecDescent::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched subrule: [PNOTQUOTED]<< (return value: [}
                    . $_tok . q{]},
                      
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PNOTQUOTED}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_trace(q{Trying action},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PNOTQUOTED}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        


        Parse::RecDescent::_trace(q{>>Matched production: [PNOTQUOTED]<<},
                      Parse::RecDescent::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_tracefirst($_[1]),
                     q{PVALUE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_trace(q{>>Accepted scored production<<}, "",
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PVALUE},
                      $tracelevel);
        Parse::RecDescent::_trace(q{(consumed: [} .
                      Parse::RecDescent::_tracemax(substr($_[1],0,-length($text))) . q{])}, 
                      Parse::RecDescent::_tracefirst($text),
                      , q{PVALUE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}
}
package Treex::Core::ScenarioParser; sub new { my $self = bless( {
                 '_precompiled' => 1,
                 'localvars' => '',
                 'startcode' => '',
                 'namespace' => 'Parse::RecDescent::Treex::Core::ScenarioParser',
                 'rules' => {
                              'SPACE' => bless( {
                                                  'impcount' => 0,
                                                  'calls' => [],
                                                  'changed' => 0,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => 0,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 1,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'pattern' => '\\s+',
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'description' => '/\\\\s+/',
                                                                                              'lookahead' => 0,
                                                                                              'rdelim' => '/',
                                                                                              'line' => 63,
                                                                                              'mod' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::Token' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 63,
                                                                                              'code' => '{$return = $item[1]}'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' )
                                                             ],
                                                  'name' => 'SPACE',
                                                  'vars' => '',
                                                  'line' => 63
                                                }, 'Parse::RecDescent::Rule' ),
                              'EMPTY' => bless( {
                                                  'impcount' => 0,
                                                  'calls' => [],
                                                  'changed' => 0,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => 0,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 1,
                                                                        'actcount' => 0,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'pattern' => '',
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'description' => '//',
                                                                                              'lookahead' => 0,
                                                                                              'rdelim' => '/',
                                                                                              'line' => 64,
                                                                                              'mod' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::Token' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' )
                                                             ],
                                                  'name' => 'EMPTY',
                                                  'vars' => '',
                                                  'line' => 64
                                                }, 'Parse::RecDescent::Rule' ),
                              'PNOTQUOTED' => bless( {
                                                       'impcount' => 0,
                                                       'calls' => [
                                                                    'EMPTY'
                                                                  ],
                                                       'changed' => 0,
                                                       'opcount' => 0,
                                                       'prods' => [
                                                                    bless( {
                                                                             'number' => 0,
                                                                             'strcount' => 0,
                                                                             'dircount' => 0,
                                                                             'uncommit' => undef,
                                                                             'error' => undef,
                                                                             'patcount' => 1,
                                                                             'actcount' => 1,
                                                                             'items' => [
                                                                                          bless( {
                                                                                                   'pattern' => '\\S+',
                                                                                                   'hashname' => '__PATTERN1__',
                                                                                                   'description' => '/\\\\S+/',
                                                                                                   'lookahead' => 0,
                                                                                                   'rdelim' => '/',
                                                                                                   'line' => 59,
                                                                                                   'mod' => '',
                                                                                                   'ldelim' => '/'
                                                                                                 }, 'Parse::RecDescent::Token' ),
                                                                                          bless( {
                                                                                                   'hashname' => '__ACTION1__',
                                                                                                   'lookahead' => 0,
                                                                                                   'line' => 59,
                                                                                                   'code' => '{$return = $item[1]}'
                                                                                                 }, 'Parse::RecDescent::Action' )
                                                                                        ],
                                                                             'line' => undef
                                                                           }, 'Parse::RecDescent::Production' ),
                                                                    bless( {
                                                                             'number' => 1,
                                                                             'strcount' => 0,
                                                                             'dircount' => 0,
                                                                             'uncommit' => undef,
                                                                             'error' => undef,
                                                                             'patcount' => 0,
                                                                             'actcount' => 1,
                                                                             'items' => [
                                                                                          bless( {
                                                                                                   'subrule' => 'EMPTY',
                                                                                                   'matchrule' => 0,
                                                                                                   'implicit' => undef,
                                                                                                   'argcode' => undef,
                                                                                                   'lookahead' => 0,
                                                                                                   'line' => 60
                                                                                                 }, 'Parse::RecDescent::Subrule' ),
                                                                                          bless( {
                                                                                                   'hashname' => '__ACTION1__',
                                                                                                   'lookahead' => 0,
                                                                                                   'line' => 60,
                                                                                                   'code' => '{$return = \'\'}'
                                                                                                 }, 'Parse::RecDescent::Action' )
                                                                                        ],
                                                                             'line' => undef
                                                                           }, 'Parse::RecDescent::Production' )
                                                                  ],
                                                       'name' => 'PNOTQUOTED',
                                                       'vars' => '',
                                                       'line' => 59
                                                     }, 'Parse::RecDescent::Rule' ),
                              'SLASHEDSQUOTE' => bless( {
                                                          'impcount' => 0,
                                                          'calls' => [],
                                                          'changed' => 0,
                                                          'opcount' => 0,
                                                          'prods' => [
                                                                       bless( {
                                                                                'number' => 0,
                                                                                'strcount' => 0,
                                                                                'dircount' => 0,
                                                                                'uncommit' => undef,
                                                                                'error' => undef,
                                                                                'patcount' => 1,
                                                                                'actcount' => 1,
                                                                                'items' => [
                                                                                             bless( {
                                                                                                      'pattern' => '\\\\\'',
                                                                                                      'hashname' => '__PATTERN1__',
                                                                                                      'description' => '/\\\\\\\\\'/',
                                                                                                      'lookahead' => 0,
                                                                                                      'rdelim' => '/',
                                                                                                      'line' => 57,
                                                                                                      'mod' => '',
                                                                                                      'ldelim' => '/'
                                                                                                    }, 'Parse::RecDescent::Token' ),
                                                                                             bless( {
                                                                                                      'hashname' => '__ACTION1__',
                                                                                                      'lookahead' => 0,
                                                                                                      'line' => 57,
                                                                                                      'code' => '{$return = "\'"}'
                                                                                                    }, 'Parse::RecDescent::Action' )
                                                                                           ],
                                                                                'line' => undef
                                                                              }, 'Parse::RecDescent::Production' )
                                                                     ],
                                                          'name' => 'SLASHEDSQUOTE',
                                                          'vars' => '',
                                                          'line' => 57
                                                        }, 'Parse::RecDescent::Rule' ),
                              'COMMENT' => bless( {
                                                    'impcount' => 0,
                                                    'calls' => [],
                                                    'changed' => 0,
                                                    'opcount' => 0,
                                                    'prods' => [
                                                                 bless( {
                                                                          'number' => 0,
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 1,
                                                                          'actcount' => 1,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'pattern' => '#[^\\n]*',
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'description' => '/#[^\\\\n]*/',
                                                                                                'lookahead' => 0,
                                                                                                'rdelim' => '/',
                                                                                                'line' => 62,
                                                                                                'mod' => '',
                                                                                                'ldelim' => '/'
                                                                                              }, 'Parse::RecDescent::Token' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 62,
                                                                                                'code' => '{$return = \'\'}'
                                                                                              }, 'Parse::RecDescent::Action' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' )
                                                               ],
                                                    'name' => 'COMMENT',
                                                    'vars' => '',
                                                    'line' => 62
                                                  }, 'Parse::RecDescent::Rule' ),
                              'EOF' => bless( {
                                                'impcount' => 0,
                                                'calls' => [],
                                                'changed' => 0,
                                                'opcount' => 0,
                                                'prods' => [
                                                             bless( {
                                                                      'number' => 0,
                                                                      'strcount' => 0,
                                                                      'dircount' => 0,
                                                                      'uncommit' => undef,
                                                                      'error' => undef,
                                                                      'patcount' => 1,
                                                                      'actcount' => 0,
                                                                      'items' => [
                                                                                   bless( {
                                                                                            'pattern' => '^\\Z',
                                                                                            'hashname' => '__PATTERN1__',
                                                                                            'description' => '/^\\\\Z/',
                                                                                            'lookahead' => 0,
                                                                                            'rdelim' => '/',
                                                                                            'line' => 14,
                                                                                            'mod' => '',
                                                                                            'ldelim' => '/'
                                                                                          }, 'Parse::RecDescent::Token' )
                                                                                 ],
                                                                      'line' => undef
                                                                    }, 'Parse::RecDescent::Production' )
                                                           ],
                                                'name' => 'EOF',
                                                'vars' => '',
                                                'line' => 14
                                              }, 'Parse::RecDescent::Rule' ),
                              'NOTSQUOTE' => bless( {
                                                      'impcount' => 0,
                                                      'calls' => [],
                                                      'changed' => 0,
                                                      'opcount' => 0,
                                                      'prods' => [
                                                                   bless( {
                                                                            'number' => 0,
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 1,
                                                                            'actcount' => 0,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'pattern' => '[^\']*[^\'\\\\]',
                                                                                                  'hashname' => '__PATTERN1__',
                                                                                                  'description' => '/[^\']*[^\'\\\\\\\\]/',
                                                                                                  'lookahead' => 0,
                                                                                                  'rdelim' => '/',
                                                                                                  'line' => 56,
                                                                                                  'mod' => '',
                                                                                                  'ldelim' => '/'
                                                                                                }, 'Parse::RecDescent::Token' )
                                                                                       ],
                                                                            'line' => undef
                                                                          }, 'Parse::RecDescent::Production' )
                                                                 ],
                                                      'name' => 'NOTSQUOTE',
                                                      'vars' => '',
                                                      'line' => 56
                                                    }, 'Parse::RecDescent::Rule' ),
                              'TBNAME' => bless( {
                                                   'impcount' => 0,
                                                   'calls' => [
                                                                'BNAME'
                                                              ],
                                                   'changed' => 0,
                                                   'opcount' => 0,
                                                   'prods' => [
                                                                bless( {
                                                                         'number' => 0,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 1,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'pattern' => '::',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'description' => '/::/',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 42,
                                                                                               'mod' => '',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'subrule' => 'BNAME',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 42
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 42,
                                                                                               'code' => '{$return = $item{BNAME}}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' ),
                                                                bless( {
                                                                         'number' => 1,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 0,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'subrule' => 'BNAME',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 43
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 43,
                                                                                               'code' => '{$return = "Treex::Block::$item{BNAME}"}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' )
                                                              ],
                                                   'name' => 'TBNAME',
                                                   'vars' => '',
                                                   'line' => 42
                                                 }, 'Parse::RecDescent::Rule' ),
                              'startrule' => bless( {
                                                      'impcount' => 0,
                                                      'calls' => [
                                                                   'SCEN',
                                                                   'EOF'
                                                                 ],
                                                      'changed' => 0,
                                                      'opcount' => 0,
                                                      'prods' => [
                                                                   bless( {
                                                                            'number' => 0,
                                                                            'strcount' => 0,
                                                                            'dircount' => 0,
                                                                            'uncommit' => undef,
                                                                            'error' => undef,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'subrule' => 'SCEN',
                                                                                                  'matchrule' => 0,
                                                                                                  'implicit' => undef,
                                                                                                  'argcode' => undef,
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 8
                                                                                                }, 'Parse::RecDescent::Subrule' ),
                                                                                         bless( {
                                                                                                  'subrule' => 'EOF',
                                                                                                  'matchrule' => 0,
                                                                                                  'implicit' => undef,
                                                                                                  'argcode' => undef,
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 8
                                                                                                }, 'Parse::RecDescent::Subrule' ),
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 8,
                                                                                                  'code' => '{$return = $item{SCEN}}'
                                                                                                }, 'Parse::RecDescent::Action' )
                                                                                       ],
                                                                            'line' => undef
                                                                          }, 'Parse::RecDescent::Production' )
                                                                 ],
                                                      'name' => 'startrule',
                                                      'vars' => '',
                                                      'line' => 8
                                                    }, 'Parse::RecDescent::Rule' ),
                              'LINE' => bless( {
                                                 'impcount' => 0,
                                                 'calls' => [
                                                              'BLOCK',
                                                              'COMMENT'
                                                            ],
                                                 'changed' => 0,
                                                 'opcount' => 0,
                                                 'prods' => [
                                                              bless( {
                                                                       'number' => 0,
                                                                       'strcount' => 0,
                                                                       'dircount' => 0,
                                                                       'uncommit' => undef,
                                                                       'error' => undef,
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'subrule' => 'BLOCK',
                                                                                             'matchrule' => 0,
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'lookahead' => 0,
                                                                                             'line' => 11
                                                                                           }, 'Parse::RecDescent::Subrule' ),
                                                                                    bless( {
                                                                                             'subrule' => 'COMMENT',
                                                                                             'matchrule' => 0,
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'lookahead' => 0,
                                                                                             'line' => 11
                                                                                           }, 'Parse::RecDescent::Subrule' ),
                                                                                    bless( {
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'lookahead' => 0,
                                                                                             'line' => 11,
                                                                                             'code' => '{$return = [@{$item{BLOCK}}]}'
                                                                                           }, 'Parse::RecDescent::Action' )
                                                                                  ],
                                                                       'line' => undef
                                                                     }, 'Parse::RecDescent::Production' ),
                                                              bless( {
                                                                       'number' => 1,
                                                                       'strcount' => 0,
                                                                       'dircount' => 0,
                                                                       'uncommit' => undef,
                                                                       'error' => undef,
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'subrule' => 'BLOCK',
                                                                                             'matchrule' => 0,
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'lookahead' => 0,
                                                                                             'line' => 12
                                                                                           }, 'Parse::RecDescent::Subrule' ),
                                                                                    bless( {
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'lookahead' => 0,
                                                                                             'line' => 12,
                                                                                             'code' => '{$return = [@{$item{BLOCK}}]}'
                                                                                           }, 'Parse::RecDescent::Action' )
                                                                                  ],
                                                                       'line' => undef
                                                                     }, 'Parse::RecDescent::Production' ),
                                                              bless( {
                                                                       'number' => 2,
                                                                       'strcount' => 0,
                                                                       'dircount' => 0,
                                                                       'uncommit' => undef,
                                                                       'error' => undef,
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'subrule' => 'COMMENT',
                                                                                             'matchrule' => 0,
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'lookahead' => 0,
                                                                                             'line' => 13
                                                                                           }, 'Parse::RecDescent::Subrule' ),
                                                                                    bless( {
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'lookahead' => 0,
                                                                                             'line' => 13,
                                                                                             'code' => '{$return = []}'
                                                                                           }, 'Parse::RecDescent::Action' )
                                                                                  ],
                                                                       'line' => undef
                                                                     }, 'Parse::RecDescent::Production' )
                                                            ],
                                                 'name' => 'LINE',
                                                 'vars' => '',
                                                 'line' => 11
                                               }, 'Parse::RecDescent::Rule' ),
                              'BLOCK' => bless( {
                                                  'impcount' => 0,
                                                  'calls' => [
                                                               'INCLUDE',
                                                               'TBNAME',
                                                               'PARAMS'
                                                             ],
                                                  'changed' => 0,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => 0,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 0,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'subrule' => 'INCLUDE',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 15
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 15,
                                                                                              'code' => '{
                                                    my $included = read_file( $item{INCLUDE} );
                                                    my $result = $thisparser->startrule( $included, 1, $item{INCLUDE} );
                                                    if (defined $result and ref $result eq \'ARRAY\') {
                                                        $return = [@$result];
                                                    } else {
                                                        $return = undef;
                                                    }
                                                }'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' ),
                                                               bless( {
                                                                        'number' => 1,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 0,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'subrule' => 'TBNAME',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 24
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'subrule' => 'PARAMS',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 24
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 24,
                                                                                              'code' => '{$return = [{
                                                        block_name=>$item{TBNAME},
                                                        block_parameters=>$item{PARAMS},
                                                    }]
                                                }'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' ),
                                                               bless( {
                                                                        'number' => 2,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 0,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'subrule' => 'TBNAME',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 29
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 29,
                                                                                              'code' => '{$return = [{
                                                        block_name=>$item{TBNAME},
                                                        block_parameters=>[],
                                                    }]
                                                }'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' )
                                                             ],
                                                  'name' => 'BLOCK',
                                                  'vars' => '',
                                                  'line' => 15
                                                }, 'Parse::RecDescent::Rule' ),
                              'PNAME' => bless( {
                                                  'impcount' => 0,
                                                  'calls' => [],
                                                  'changed' => 0,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => 0,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 1,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'pattern' => '\\w+',
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'description' => '/\\\\w+/',
                                                                                              'lookahead' => 0,
                                                                                              'rdelim' => '/',
                                                                                              'line' => 49,
                                                                                              'mod' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::Token' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 49,
                                                                                              'code' => '{$return = $item[1]}'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' )
                                                             ],
                                                  'name' => 'PNAME',
                                                  'vars' => '',
                                                  'line' => 49
                                                }, 'Parse::RecDescent::Rule' ),
                              'PTICKED' => bless( {
                                                    'impcount' => 0,
                                                    'calls' => [],
                                                    'changed' => 0,
                                                    'opcount' => 0,
                                                    'prods' => [
                                                                 bless( {
                                                                          'number' => 0,
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 1,
                                                                          'actcount' => 1,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'pattern' => '[^`]+',
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'description' => '/[^`]+/',
                                                                                                'lookahead' => 0,
                                                                                                'rdelim' => '/',
                                                                                                'line' => 61,
                                                                                                'mod' => '',
                                                                                                'ldelim' => '/'
                                                                                              }, 'Parse::RecDescent::Token' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 61,
                                                                                                'code' => '{$return = $item[1]}'
                                                                                              }, 'Parse::RecDescent::Action' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' )
                                                               ],
                                                    'name' => 'PTICKED',
                                                    'vars' => '',
                                                    'line' => 61
                                                  }, 'Parse::RecDescent::Rule' ),
                              'BNAME' => bless( {
                                                  'impcount' => 0,
                                                  'calls' => [
                                                               'BNAME'
                                                             ],
                                                  'changed' => 0,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => 0,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 1,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'pattern' => '[A-Z]\\w*::',
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'description' => '/[A-Z]\\\\w*::/',
                                                                                              'lookahead' => 0,
                                                                                              'rdelim' => '/',
                                                                                              'line' => 44,
                                                                                              'mod' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::Token' ),
                                                                                     bless( {
                                                                                              'subrule' => 'BNAME',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 44
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 44,
                                                                                              'code' => '{$return = $item[1].$item[2]}'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' ),
                                                               bless( {
                                                                        'number' => 1,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 1,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'pattern' => '[A-Z]\\w*',
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'description' => '/[A-Z]\\\\w*/',
                                                                                              'lookahead' => 0,
                                                                                              'rdelim' => '/',
                                                                                              'line' => 45,
                                                                                              'mod' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::Token' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 45,
                                                                                              'code' => '{$return = $item[1]}'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' )
                                                             ],
                                                  'name' => 'BNAME',
                                                  'vars' => '',
                                                  'line' => 43
                                                }, 'Parse::RecDescent::Rule' ),
                              'SCEN' => bless( {
                                                 'impcount' => 0,
                                                 'calls' => [
                                                              'LINE',
                                                              'SCEN'
                                                            ],
                                                 'changed' => 0,
                                                 'opcount' => 0,
                                                 'prods' => [
                                                              bless( {
                                                                       'number' => 0,
                                                                       'strcount' => 0,
                                                                       'dircount' => 0,
                                                                       'uncommit' => undef,
                                                                       'error' => undef,
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'subrule' => 'LINE',
                                                                                             'matchrule' => 0,
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'lookahead' => 0,
                                                                                             'line' => 9
                                                                                           }, 'Parse::RecDescent::Subrule' ),
                                                                                    bless( {
                                                                                             'subrule' => 'SCEN',
                                                                                             'matchrule' => 0,
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'lookahead' => 0,
                                                                                             'line' => 9
                                                                                           }, 'Parse::RecDescent::Subrule' ),
                                                                                    bless( {
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'lookahead' => 0,
                                                                                             'line' => 9,
                                                                                             'code' => '{$return = [@{$item{LINE}},@{$item{SCEN}}]}'
                                                                                           }, 'Parse::RecDescent::Action' )
                                                                                  ],
                                                                       'line' => undef
                                                                     }, 'Parse::RecDescent::Production' ),
                                                              bless( {
                                                                       'number' => 1,
                                                                       'strcount' => 0,
                                                                       'dircount' => 0,
                                                                       'uncommit' => undef,
                                                                       'error' => undef,
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'subrule' => 'LINE',
                                                                                             'matchrule' => 0,
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'lookahead' => 0,
                                                                                             'line' => 10
                                                                                           }, 'Parse::RecDescent::Subrule' ),
                                                                                    bless( {
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'lookahead' => 0,
                                                                                             'line' => 10,
                                                                                             'code' => '{$return = [@{$item{LINE}}]}'
                                                                                           }, 'Parse::RecDescent::Action' )
                                                                                  ],
                                                                       'line' => undef
                                                                     }, 'Parse::RecDescent::Production' )
                                                            ],
                                                 'name' => 'SCEN',
                                                 'vars' => '',
                                                 'line' => 9
                                               }, 'Parse::RecDescent::Rule' ),
                              'INCLUDE' => bless( {
                                                    'impcount' => 0,
                                                    'calls' => [],
                                                    'changed' => 0,
                                                    'opcount' => 0,
                                                    'prods' => [
                                                                 bless( {
                                                                          'number' => 0,
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 1,
                                                                          'actcount' => 1,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'pattern' => '\\/\\S+\\.scen',
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'description' => '/\\\\/\\\\S+\\\\.scen/',
                                                                                                'lookahead' => 0,
                                                                                                'rdelim' => '/',
                                                                                                'line' => 34,
                                                                                                'mod' => '',
                                                                                                'ldelim' => '/'
                                                                                              }, 'Parse::RecDescent::Token' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 34,
                                                                                                'code' => '{$return = $item[1]}'
                                                                                              }, 'Parse::RecDescent::Action' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' ),
                                                                 bless( {
                                                                          'number' => 1,
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 1,
                                                                          'actcount' => 1,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'pattern' => '[^\\/#]\\S+\\.scen',
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'description' => '/[^\\\\/#]\\\\S+\\\\.scen/',
                                                                                                'lookahead' => 0,
                                                                                                'rdelim' => '/',
                                                                                                'line' => 35,
                                                                                                'mod' => '',
                                                                                                'ldelim' => '/'
                                                                                              }, 'Parse::RecDescent::Token' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 35,
                                                                                                'code' => '{   my $from_file = $arg[0];
                                                    if ($from_file =~ /./) {
                                                        $return = dirname($from_file) . "/$item[1]";
                                                    } else {
                                                        $return = "./$item[1]";
                                                    }
                                                }'
                                                                                              }, 'Parse::RecDescent::Action' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' )
                                                               ],
                                                    'name' => 'INCLUDE',
                                                    'vars' => '',
                                                    'line' => 34
                                                  }, 'Parse::RecDescent::Rule' ),
                              'PDQUOTE' => bless( {
                                                    'impcount' => 0,
                                                    'calls' => [],
                                                    'changed' => 0,
                                                    'opcount' => 0,
                                                    'prods' => [
                                                                 bless( {
                                                                          'number' => 0,
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 1,
                                                                          'actcount' => 1,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'pattern' => '[^"]*',
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'description' => '/[^"]*/',
                                                                                                'lookahead' => 0,
                                                                                                'rdelim' => '/',
                                                                                                'line' => 58,
                                                                                                'mod' => '',
                                                                                                'ldelim' => '/'
                                                                                              }, 'Parse::RecDescent::Token' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 58,
                                                                                                'code' => '{$return = $item[1]}'
                                                                                              }, 'Parse::RecDescent::Action' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' )
                                                               ],
                                                    'name' => 'PDQUOTE',
                                                    'vars' => '',
                                                    'line' => 58
                                                  }, 'Parse::RecDescent::Rule' ),
                              'PSQUOTE' => bless( {
                                                    'impcount' => 0,
                                                    'calls' => [
                                                                 'NOTSQUOTE',
                                                                 'SLASHEDSQUOTE',
                                                                 'PSQUOTE'
                                                               ],
                                                    'changed' => 0,
                                                    'opcount' => 0,
                                                    'prods' => [
                                                                 bless( {
                                                                          'number' => 0,
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 0,
                                                                          'actcount' => 1,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'subrule' => 'NOTSQUOTE',
                                                                                                'matchrule' => 0,
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef,
                                                                                                'lookahead' => 0,
                                                                                                'line' => 54
                                                                                              }, 'Parse::RecDescent::Subrule' ),
                                                                                       bless( {
                                                                                                'subrule' => 'SLASHEDSQUOTE',
                                                                                                'matchrule' => 0,
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef,
                                                                                                'lookahead' => 0,
                                                                                                'line' => 54
                                                                                              }, 'Parse::RecDescent::Subrule' ),
                                                                                       bless( {
                                                                                                'subrule' => 'PSQUOTE',
                                                                                                'matchrule' => 0,
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef,
                                                                                                'lookahead' => 0,
                                                                                                'line' => 54
                                                                                              }, 'Parse::RecDescent::Subrule' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 54,
                                                                                                'code' => '{$return = $item{NOTSQUOTE}.$item{SLASHEDSQUOTE}.$item{PSQUOTE}}'
                                                                                              }, 'Parse::RecDescent::Action' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' ),
                                                                 bless( {
                                                                          'number' => 1,
                                                                          'strcount' => 0,
                                                                          'dircount' => 0,
                                                                          'uncommit' => undef,
                                                                          'error' => undef,
                                                                          'patcount' => 0,
                                                                          'actcount' => 0,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'subrule' => 'NOTSQUOTE',
                                                                                                'matchrule' => 0,
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef,
                                                                                                'lookahead' => 0,
                                                                                                'line' => 55
                                                                                              }, 'Parse::RecDescent::Subrule' )
                                                                                     ],
                                                                          'line' => undef
                                                                        }, 'Parse::RecDescent::Production' )
                                                               ],
                                                    'name' => 'PSQUOTE',
                                                    'vars' => '',
                                                    'line' => 54
                                                  }, 'Parse::RecDescent::Rule' ),
                              'PARAMS' => bless( {
                                                   'impcount' => 0,
                                                   'calls' => [
                                                                'PARAM',
                                                                'PARAMS'
                                                              ],
                                                   'changed' => 0,
                                                   'opcount' => 0,
                                                   'prods' => [
                                                                bless( {
                                                                         'number' => 0,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 0,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'subrule' => 'PARAM',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 46
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'subrule' => 'PARAMS',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 46
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 46,
                                                                                               'code' => '{$return = [$item{PARAM}, @{$item{PARAMS}}]}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' ),
                                                                bless( {
                                                                         'number' => 1,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 0,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'subrule' => 'PARAM',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 47
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 47,
                                                                                               'code' => '{$return = [$item{PARAM}]}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' )
                                                              ],
                                                   'name' => 'PARAMS',
                                                   'vars' => '',
                                                   'line' => 46
                                                 }, 'Parse::RecDescent::Rule' ),
                              'PARAM' => bless( {
                                                  'impcount' => 0,
                                                  'calls' => [
                                                               'PNAME',
                                                               'PVALUE'
                                                             ],
                                                  'changed' => 0,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => 0,
                                                                        'strcount' => 1,
                                                                        'dircount' => 1,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'patcount' => 0,
                                                                        'actcount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'subrule' => 'PNAME',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 48
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'pattern' => '=',
                                                                                              'hashname' => '__STRING1__',
                                                                                              'description' => '\'=\'',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 48
                                                                                            }, 'Parse::RecDescent::Literal' ),
                                                                                     bless( {
                                                                                              'hashname' => '__DIRECTIVE1__',
                                                                                              'name' => '<skip: qr//>',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 48,
                                                                                              'code' => 'my $oldskip = $skip; $skip= qr//; $oldskip'
                                                                                            }, 'Parse::RecDescent::Directive' ),
                                                                                     bless( {
                                                                                              'subrule' => 'PVALUE',
                                                                                              'matchrule' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'line' => 48
                                                                                            }, 'Parse::RecDescent::Subrule' ),
                                                                                     bless( {
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 48,
                                                                                              'code' => '{$return = $item{PNAME}.\'=\'.$item{PVALUE}}'
                                                                                            }, 'Parse::RecDescent::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::Production' )
                                                             ],
                                                  'name' => 'PARAM',
                                                  'vars' => '',
                                                  'line' => 48
                                                }, 'Parse::RecDescent::Rule' ),
                              'PVALUE' => bless( {
                                                   'impcount' => 0,
                                                   'calls' => [
                                                                'PSQUOTE',
                                                                'PDQUOTE',
                                                                'PTICKED',
                                                                'PNOTQUOTED'
                                                              ],
                                                   'changed' => 0,
                                                   'opcount' => 0,
                                                   'prods' => [
                                                                bless( {
                                                                         'number' => 0,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 2,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'pattern' => '\'',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'description' => '/\'/',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 50,
                                                                                               'mod' => '',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'subrule' => 'PSQUOTE',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 50
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'pattern' => '\'',
                                                                                               'hashname' => '__PATTERN2__',
                                                                                               'description' => '/\'/',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 50,
                                                                                               'mod' => '',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 50,
                                                                                               'code' => '{$return = $item{PSQUOTE}}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' ),
                                                                bless( {
                                                                         'number' => 1,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 2,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'pattern' => '"',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'description' => '/"/',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 51,
                                                                                               'mod' => '',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'subrule' => 'PDQUOTE',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 51
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'pattern' => '"',
                                                                                               'hashname' => '__PATTERN2__',
                                                                                               'description' => '/"/',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 51,
                                                                                               'mod' => '',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 51,
                                                                                               'code' => '{$return = $item{PDQUOTE}}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' ),
                                                                bless( {
                                                                         'number' => 2,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 2,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'pattern' => '`',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'description' => '/`/',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 52,
                                                                                               'mod' => '',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'subrule' => 'PTICKED',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 52
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'pattern' => '`',
                                                                                               'hashname' => '__PATTERN2__',
                                                                                               'description' => '/`/',
                                                                                               'lookahead' => 0,
                                                                                               'rdelim' => '/',
                                                                                               'line' => 52,
                                                                                               'mod' => '',
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::Token' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 52,
                                                                                               'code' => '{$return = $item[1].$item[2].$item[3]}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' ),
                                                                bless( {
                                                                         'number' => 3,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'error' => undef,
                                                                         'patcount' => 0,
                                                                         'actcount' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'subrule' => 'PNOTQUOTED',
                                                                                               'matchrule' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'lookahead' => 0,
                                                                                               'line' => 53
                                                                                             }, 'Parse::RecDescent::Subrule' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 53,
                                                                                               'code' => '{$return = $item{PNOTQUOTED}}'
                                                                                             }, 'Parse::RecDescent::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::Production' )
                                                              ],
                                                   'name' => 'PVALUE',
                                                   'vars' => '',
                                                   'line' => 50
                                                 }, 'Parse::RecDescent::Rule' )
                            },
                 '_AUTOTREE' => undef,
                 '_check' => {
                               'thisoffset' => '',
                               'itempos' => '',
                               'prevoffset' => '',
                               'prevline' => '',
                               'prevcolumn' => '',
                               'thiscolumn' => ''
                             },
                 '_AUTOACTION' => undef
               }, 'Parse::RecDescent' );
}
