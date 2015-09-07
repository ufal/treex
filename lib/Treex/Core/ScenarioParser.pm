## no critic (Miscellanea::ProhibitUnrestrictedNoCritic)
## no critic Generated code follows
{
# GENERATE RECURSIVE DESCENT PARSER OBJECTS FROM A GRAMMAR

use 5.006;
use strict;

package Parse::RecDescent::_Runtime;

use Text::Balanced qw ( extract_codeblock extract_bracketed extract_quotelike extract_delimited );

use vars qw ( $skip );

   *defskip  = \ '\s*'; # DEFAULT SEPARATOR IS OPTIONAL WHITESPACE
   $skip  = '\s*';      # UNIVERSAL SEPARATOR IS OPTIONAL WHITESPACE
my $MAXREP  = 100_000_000;  # REPETITIONS MATCH AT MOST 100,000,000 TIMES



package Parse::RecDescent::_Runtime::LineCounter;


sub TIESCALAR   # ($classname, \$text, $thisparser, $prevflag)
{
    bless {
        text    => $_[1],
        parser  => $_[2],
        prev    => $_[3]?1:0,
          }, $_[0];
}

sub FETCH
{
    my $parser = $_[0]->{parser};
    my $cache = $parser->{linecounter_cache};
    my $from = $parser->{fulltextlen}-length(${$_[0]->{text}})-$_[0]->{prev}
;

    unless (exists $cache->{$from})
    {
        $parser->{lastlinenum} = $parser->{offsetlinenum}
          - Parse::RecDescent::_Runtime::_linecount(substr($parser->{fulltext},$from))
          + 1;
        $cache->{$from} = $parser->{lastlinenum};
    }
    return $cache->{$from};
}

sub STORE
{
    my $parser = $_[0]->{parser};
    $parser->{offsetlinenum} -= $parser->{lastlinenum} - $_[1];
    return undef;
}

sub resync   # ($linecounter)
{
    my $self = tied($_[0]);
    die "Tried to alter something other than a LineCounter\n"
        unless $self =~ /Parse::RecDescent::_Runtime::LineCounter/;

    my $parser = $self->{parser};
    my $apparently = $parser->{offsetlinenum}
             - Parse::RecDescent::_Runtime::_linecount(${$self->{text}})
             + 1;

    $parser->{offsetlinenum} += $parser->{lastlinenum} - $apparently;
    return 1;
}

package Parse::RecDescent::_Runtime::ColCounter;

sub TIESCALAR   # ($classname, \$text, $thisparser, $prevflag)
{
    bless {
        text    => $_[1],
        parser  => $_[2],
        prev    => $_[3]?1:0,
          }, $_[0];
}

sub FETCH
{
    my $parser = $_[0]->{parser};
    my $missing = $parser->{fulltextlen}-length(${$_[0]->{text}})-$_[0]->{prev}+1;
    substr($parser->{fulltext},0,$missing) =~ m/^(.*)\Z/m;
    return length($1);
}

sub STORE
{
    die "Can't set column number via \$thiscolumn\n";
}


package Parse::RecDescent::_Runtime::OffsetCounter;

sub TIESCALAR   # ($classname, \$text, $thisparser, $prev)
{
    bless {
        text    => $_[1],
        parser  => $_[2],
        prev    => $_[3]?-1:0,
          }, $_[0];
}

sub FETCH
{
    my $parser = $_[0]->{parser};
    return $parser->{fulltextlen}-length(${$_[0]->{text}})+$_[0]->{prev};
}

sub STORE
{
    die "Can't set current offset via \$thisoffset or \$prevoffset\n";
}



package Parse::RecDescent::_Runtime::Rule;

sub new ($$$$$)
{
    my $class = ref($_[0]) || $_[0];
    my $name  = $_[1];
    my $owner = $_[2];
    my $line  = $_[3];
    my $replace = $_[4];

    if (defined $owner->{"rules"}{$name})
    {
        my $self = $owner->{"rules"}{$name};
        if ($replace && !$self->{"changed"})
        {
            $self->reset;
        }
        return $self;
    }
    else
    {
        return $owner->{"rules"}{$name} =
            bless
            {
                "name"     => $name,
                "prods"    => [],
                "calls"    => [],
                "changed"  => 0,
                "line"     => $line,
                "impcount" => 0,
                "opcount"  => 0,
                "vars"     => "",
            }, $class;
    }
}

sub reset($)
{
    @{$_[0]->{"prods"}} = ();
    @{$_[0]->{"calls"}} = ();
    $_[0]->{"changed"}  = 0;
    $_[0]->{"impcount"}  = 0;
    $_[0]->{"opcount"}  = 0;
    $_[0]->{"vars"}  = "";
}

sub DESTROY {}

sub hasleftmost($$)
{
    my ($self, $ref) = @_;

    my $prod;
    foreach $prod ( @{$self->{"prods"}} )
    {
        return 1 if $prod->hasleftmost($ref);
    }

    return 0;
}

sub leftmostsubrules($)
{
    my $self = shift;
    my @subrules = ();

    my $prod;
    foreach $prod ( @{$self->{"prods"}} )
    {
        push @subrules, $prod->leftmostsubrule();
    }

    return @subrules;
}

sub expected($)
{
    my $self = shift;
    my @expected = ();

    my $prod;
    foreach $prod ( @{$self->{"prods"}} )
    {
        my $next = $prod->expected();
        unless (! $next or _contains($next,@expected) )
        {
            push @expected, $next;
        }
    }

    return join ', or ', @expected;
}

sub _contains($@)
{
    my $target = shift;
    my $item;
    foreach $item ( @_ ) { return 1 if $target eq $item; }
    return 0;
}

sub addcall($$)
{
    my ( $self, $subrule ) = @_;
    unless ( _contains($subrule, @{$self->{"calls"}}) )
    {
        push @{$self->{"calls"}}, $subrule;
    }
}

sub addprod($$)
{
    my ( $self, $prod ) = @_;
    push @{$self->{"prods"}}, $prod;
    $self->{"changed"} = 1;
    $self->{"impcount"} = 0;
    $self->{"opcount"} = 0;
    $prod->{"number"} = $#{$self->{"prods"}};
    return $prod;
}

sub addvar
{
    my ( $self, $var, $parser ) = @_;
    if ($var =~ /\A\s*local\s+([%@\$]\w+)/)
    {
        $parser->{localvars} .= " $1";
        $self->{"vars"} .= "$var;\n" }
    else
        { $self->{"vars"} .= "my $var;\n" }
    $self->{"changed"} = 1;
    return 1;
}

sub addautoscore
{
    my ( $self, $code ) = @_;
    $self->{"autoscore"} = $code;
    $self->{"changed"} = 1;
    return 1;
}

sub nextoperator($)
{
    my $self = shift;
    my $prodcount = scalar @{$self->{"prods"}};
    my $opcount = ++$self->{"opcount"};
    return "_operator_${opcount}_of_production_${prodcount}_of_rule_$self->{name}";
}

sub nextimplicit($)
{
    my $self = shift;
    my $prodcount = scalar @{$self->{"prods"}};
    my $impcount = ++$self->{"impcount"};
    return "_alternation_${impcount}_of_production_${prodcount}_of_rule_$self->{name}";
}


sub code
{
    my ($self, $namespace, $parser, $check) = @_;

eval 'undef &' . $namespace . '::' . $self->{"name"} unless $parser->{saving};

    my $code =
'
# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub ' . $namespace . '::' . $self->{"name"} .  '
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"' . $self->{"name"} . '"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [' . $self->{"name"} . ']},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                  q{' . $self->{"name"} . '},
                  $tracelevel)
                    if defined $::RD_TRACE;

    ' . ($parser->{deferrable}
        ? 'my $def_at = @{$thisparser->{deferred}};'
        : '') .
    '
    my $err_at = @{$thisparser->{errors}};

    my $score;
    my $score_return;
    my $_tok;
    my $return = undef;
    my $_matched=0;
    my $commit=0;
    my @item = ();
    my %item = ();
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{' . $self->expected() . '});
    $expectation->at($_[1]);
    '. ($parser->{_check}{thisoffset}?'
    my $thisoffset;
    tie $thisoffset, q{Parse::RecDescent::_Runtime::OffsetCounter}, \$text, $thisparser;
    ':'') . ($parser->{_check}{prevoffset}?'
    my $prevoffset;
    tie $prevoffset, q{Parse::RecDescent::_Runtime::OffsetCounter}, \$text, $thisparser, 1;
    ':'') . ($parser->{_check}{thiscolumn}?'
    my $thiscolumn;
    tie $thiscolumn, q{Parse::RecDescent::_Runtime::ColCounter}, \$text, $thisparser;
    ':'') . ($parser->{_check}{prevcolumn}?'
    my $prevcolumn;
    tie $prevcolumn, q{Parse::RecDescent::_Runtime::ColCounter}, \$text, $thisparser, 1;
    ':'') . ($parser->{_check}{prevline}?'
    my $prevline;
    tie $prevline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser, 1;
    ':'') . '
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    '. $self->{vars} .'
';

    my $prod;
    foreach $prod ( @{$self->{"prods"}} )
    {
        $prod->addscore($self->{autoscore},0,0) if $self->{autoscore};
        next unless $prod->checkleftmost();
        $code .= $prod->code($namespace,$self,$parser);

        $code .= $parser->{deferrable}
                ? '     splice
                @{$thisparser->{deferred}}, $def_at unless $_matched;
                  '
                : '';
    }

    $code .=
'
    unless ( $_matched || defined($score) )
    {
        ' .($parser->{deferrable}
            ? '     splice @{$thisparser->{deferred}}, $def_at;
              '
            : '') . '

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<'.Parse::RecDescent::_Runtime::_matchtracemessage($self,1).' rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{' . $self->{"name"} .'},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{' . $self->{"name"} .'},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>'.Parse::RecDescent::_Runtime::_matchtracemessage($self).' rule<< (return value: [} .
                      $return . q{])}, "",
                      q{' . $self->{"name"} .'},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{' . $self->{"name"} .'},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}
';

    return $code;
}

my @left;
sub isleftrec($$)
{
    my ($self, $rules) = @_;
    my $root = $self->{"name"};
    @left = $self->leftmostsubrules();
    my $next;
    foreach $next ( @left )
    {
        next unless defined $rules->{$next}; # SKIP NON-EXISTENT RULES
        return 1 if $next eq $root;
        my $child;
        foreach $child ( $rules->{$next}->leftmostsubrules() )
        {
            push(@left, $child)
            if ! _contains($child, @left) ;
        }
    }
    return 0;
}

package Parse::RecDescent::_Runtime::Production;

sub describe ($;$)
{
    return join ' ', map { $_->describe($_[1]) or () } @{$_[0]->{items}};
}

sub new ($$;$$)
{
    my ($self, $line, $uncommit, $error) = @_;
    my $class = ref($self) || $self;

    bless
    {
        "items"    => [],
        "uncommit" => $uncommit,
        "error"    => $error,
        "line"     => $line,
        strcount   => 0,
        patcount   => 0,
        dircount   => 0,
        actcount   => 0,
    }, $class;
}

sub expected ($)
{
    my $itemcount = scalar @{$_[0]->{"items"}};
    return ($itemcount) ? $_[0]->{"items"}[0]->describe(1) : '';
}

sub hasleftmost ($$)
{
    my ($self, $ref) = @_;
    return ${$self->{"items"}}[0] eq $ref  if scalar @{$self->{"items"}};
    return 0;
}

sub isempty($)
{
    my $self = shift;
    return 0 == @{$self->{"items"}};
}

sub leftmostsubrule($)
{
    my $self = shift;

    if ( $#{$self->{"items"}} >= 0 )
    {
        my $subrule = $self->{"items"}[0]->issubrule();
        return $subrule if defined $subrule;
    }

    return ();
}

sub checkleftmost($)
{
    my @items = @{$_[0]->{"items"}};
    if (@items==1 && ref($items[0]) =~ /\AParse::RecDescent::_Runtime::Error/
        && $items[0]->{commitonly} )
    {
        Parse::RecDescent::_Runtime::_warn(2,"Lone <error?> in production treated
                        as <error?> <reject>");
        Parse::RecDescent::_Runtime::_hint("A production consisting of a single
                      conditional <error?> directive would
                      normally succeed (with the value zero) if the
                      rule is not 'commited' when it is
                      tried. Since you almost certainly wanted
                      '<error?> <reject>' Parse::RecDescent::_Runtime
                      supplied it for you.");
        push @{$_[0]->{items}},
            Parse::RecDescent::_Runtime::UncondReject->new(0,0,'<reject>');
    }
    elsif (@items==1 && ($items[0]->describe||"") =~ /<rulevar|<autoscore/)
    {
        # Do nothing
    }
    elsif (@items &&
        ( ref($items[0]) =~ /\AParse::RecDescent::_Runtime::UncondReject/
        || ($items[0]->describe||"") =~ /<autoscore/
        ))
    {
        Parse::RecDescent::_Runtime::_warn(1,"Optimizing away production: [". $_[0]->describe ."]");
        my $what = $items[0]->describe =~ /<rulevar/
                ? "a <rulevar> (which acts like an unconditional <reject> during parsing)"
             : $items[0]->describe =~ /<autoscore/
                ? "an <autoscore> (which acts like an unconditional <reject> during parsing)"
                : "an unconditional <reject>";
        my $caveat = $items[0]->describe =~ /<rulevar/
                ? " after the specified variable was set up"
                : "";
        my $advice = @items > 1
                ? "However, there were also other (useless) items after the leading "
                  . $items[0]->describe
                  . ", so you may have been expecting some other behaviour."
                : "You can safely ignore this message.";
        Parse::RecDescent::_Runtime::_hint("The production starts with $what. That means that the
                      production can never successfully match, so it was
                      optimized out of the final parser$caveat. $advice");
        return 0;
    }
    return 1;
}

sub changesskip($)
{
    my $item;
    foreach $item (@{$_[0]->{"items"}})
    {
        if (ref($item) =~ /Parse::RecDescent::_Runtime::(Action|Directive)/)
        {
            return 1 if $item->{code} =~ /\$skip\s*=/;
        }
    }
    return 0;
}

sub adddirective
{
    my ( $self, $whichop, $line, $name ) = @_;
    push @{$self->{op}},
        { type=>$whichop, line=>$line, name=>$name,
          offset=> scalar(@{$self->{items}}) };
}

sub addscore
{
    my ( $self, $code, $lookahead, $line ) = @_;
    $self->additem(Parse::RecDescent::_Runtime::Directive->new(
                  "local \$^W;
                   my \$thisscore = do { $code } + 0;
                   if (!defined(\$score) || \$thisscore>\$score)
                    { \$score=\$thisscore; \$score_return=\$item[-1]; }
                   undef;", $lookahead, $line,"<score: $code>") )
        unless $self->{items}[-1]->describe =~ /<score/;
    return 1;
}

sub check_pending
{
    my ( $self, $line ) = @_;
    if ($self->{op})
    {
        while (my $next = pop @{$self->{op}})
        {
        Parse::RecDescent::_Runtime::_error("Incomplete <$next->{type}op:...>.", $line);
        Parse::RecDescent::_Runtime::_hint(
            "The current production ended without completing the
             <$next->{type}op:...> directive that started near line
             $next->{line}. Did you forget the closing '>'?");
        }
    }
    return 1;
}

sub enddirective
{
    my ( $self, $line, $minrep, $maxrep ) = @_;
    unless ($self->{op})
    {
        Parse::RecDescent::_Runtime::_error("Unmatched > found.", $line);
        Parse::RecDescent::_Runtime::_hint(
            "A '>' angle bracket was encountered, which typically
             indicates the end of a directive. However no suitable
             preceding directive was encountered. Typically this
             indicates either a extra '>' in the grammar, or a
             problem inside the previous directive.");
        return;
    }
    my $op = pop @{$self->{op}};
    my $span = @{$self->{items}} - $op->{offset};
    if ($op->{type} =~ /left|right/)
    {
        if ($span != 3)
        {
        Parse::RecDescent::_Runtime::_error(
            "Incorrect <$op->{type}op:...> specification:
             expected 3 args, but found $span instead", $line);
        Parse::RecDescent::_Runtime::_hint(
            "The <$op->{type}op:...> directive requires a
             sequence of exactly three elements. For example:
             <$op->{type}op:leftarg /op/ rightarg>");
        }
        else
        {
        push @{$self->{items}},
            Parse::RecDescent::_Runtime::Operator->new(
                $op->{type}, $minrep, $maxrep, splice(@{$self->{"items"}}, -3));
        $self->{items}[-1]->sethashname($self);
        $self->{items}[-1]{name} = $op->{name};
        }
    }
}

sub prevwasreturn
{
    my ( $self, $line ) = @_;
    unless (@{$self->{items}})
    {
        Parse::RecDescent::_Runtime::_error(
            "Incorrect <return:...> specification:
            expected item missing", $line);
        Parse::RecDescent::_Runtime::_hint(
            "The <return:...> directive requires a
            sequence of at least one item. For example:
            <return: list>");
        return;
    }
    push @{$self->{items}},
        Parse::RecDescent::_Runtime::Result->new();
}

sub additem
{
    my ( $self, $item ) = @_;
    $item->sethashname($self);
    push @{$self->{"items"}}, $item;
    return $item;
}

sub _duplicate_itempos
{
    my ($src) = @_;
    my $dst = {};

    foreach (keys %$src)
    {
        %{$dst->{$_}} = %{$src->{$_}};
    }
    $dst;
}

sub _update_itempos
{
    my ($dst, $src, $typekeys, $poskeys) = @_;

    my @typekeys = 'ARRAY' eq ref $typekeys ?
      @$typekeys :
      keys %$src;

    foreach my $k (keys %$src)
    {
        if ('ARRAY' eq ref $poskeys)
        {
            @{$dst->{$k}}{@$poskeys} = @{$src->{$k}}{@$poskeys};
        }
        else
        {
            %{$dst->{$k}} = %{$src->{$k}};
        }
    }
}

sub preitempos
{
    return q
    {
        push @itempos, {'offset' => {'from'=>$thisoffset, 'to'=>undef},
                        'line'   => {'from'=>$thisline,   'to'=>undef},
                        'column' => {'from'=>$thiscolumn, 'to'=>undef} };
    }
}

sub incitempos
{
    return q
    {
        $itempos[$#itempos]{'offset'}{'from'} += length($lastsep);
        $itempos[$#itempos]{'line'}{'from'}   = $thisline;
        $itempos[$#itempos]{'column'}{'from'} = $thiscolumn;
    }
}

sub unincitempos
{
    # the next incitempos will properly set these two fields, but
    # {'offset'}{'from'} needs to be decreased by length($lastsep)
    # $itempos[$#itempos]{'line'}{'from'}
    # $itempos[$#itempos]{'column'}{'from'}
    return q
    {
        $itempos[$#itempos]{'offset'}{'from'} -= length($lastsep) if defined $lastsep;
    }
}

sub postitempos
{
    return q
    {
        $itempos[$#itempos]{'offset'}{'to'} = $prevoffset;
        $itempos[$#itempos]{'line'}{'to'}   = $prevline;
        $itempos[$#itempos]{'column'}{'to'} = $prevcolumn;
    }
}

sub code($$$$)
{
    my ($self,$namespace,$rule,$parser) = @_;
    my $code =
'
    while (!$_matched'
    . (defined $self->{"uncommit"} ? '' : ' && !$commit')
    . ')
    {
        ' .
        ($self->changesskip()
            ? 'local $skip = defined($skip) ? $skip : $Parse::RecDescent::_Runtime::skip;'
            : '') .'
        Parse::RecDescent::_Runtime::_trace(q{Trying production: ['
                      . $self->describe . ']},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{' . $rule ->{name}. '},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[' . $self->{"number"} . '];
        ' . (defined $self->{"error"} ? '' : '$text = $_[1];' ) . '
        my $_savetext;
        @item = (q{' . $rule->{"name"} . '});
        %item = (__RULE__ => q{' . $rule->{"name"} . '});
        my $repcount = 0;

';
    $code .=
'        my @itempos = ({});
'           if $parser->{_check}{itempos};

    my $item;
    my $i;

    for ($i = 0; $i < @{$self->{"items"}}; $i++)
    {
        $item = ${$self->{items}}[$i];

        $code .= preitempos() if $parser->{_check}{itempos};

        $code .= $item->code($namespace,$rule,$parser->{_check});

        $code .= postitempos() if $parser->{_check}{itempos};

    }

    if ($parser->{_AUTOACTION} && defined($item) && !$item->isa("Parse::RecDescent::_Runtime::Action"))
    {
        $code .= $parser->{_AUTOACTION}->code($namespace,$rule);
        Parse::RecDescent::_Runtime::_warn(1,"Autogenerating action in rule
                       \"$rule->{name}\":
                        $parser->{_AUTOACTION}{code}")
        and
        Parse::RecDescent::_Runtime::_hint("The \$::RD_AUTOACTION was defined,
                      so any production not ending in an
                      explicit action has the specified
                      \"auto-action\" automatically
                      appended.");
    }
    elsif ($parser->{_AUTOTREE} && defined($item) && !$item->isa("Parse::RecDescent::_Runtime::Action"))
    {
        if ($i==1 && $item->isterminal)
        {
            $code .= $parser->{_AUTOTREE}{TERMINAL}->code($namespace,$rule);
        }
        else
        {
            $code .= $parser->{_AUTOTREE}{NODE}->code($namespace,$rule);
        }
        Parse::RecDescent::_Runtime::_warn(1,"Autogenerating tree-building action in rule
                       \"$rule->{name}\"")
        and
        Parse::RecDescent::_Runtime::_hint("The directive <autotree> was specified,
                      so any production not ending
                      in an explicit action has
                      some parse-tree building code
                      automatically appended.");
    }

    $code .=
'
        Parse::RecDescent::_Runtime::_trace(q{>>'.Parse::RecDescent::_Runtime::_matchtracemessage($self).' production: ['
                      . $self->describe . ']<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{name} . '},
                      $tracelevel)
                        if defined $::RD_TRACE;

' . ( $parser->{_check}{itempos} ? '
        if ( defined($_itempos) )
        {
            Parse::RecDescent::_Runtime::Production::_update_itempos($_itempos, $itempos[ 1], undef, [qw(from)]);
            Parse::RecDescent::_Runtime::Production::_update_itempos($_itempos, $itempos[-1], undef, [qw(to)]);
        }
' : '' ) . '

        $_matched = 1;
        last;
    }

';
    return $code;
}

1;

package Parse::RecDescent::_Runtime::Action;

sub describe { undef }

sub sethashname { $_[0]->{hashname} = '__ACTION' . ++$_[1]->{actcount} .'__'; }

sub new
{
    my $class = ref($_[0]) || $_[0];
    bless
    {
        "code"      => $_[1],
        "lookahead" => $_[2],
        "line"      => $_[3],
    }, $class;
}

sub issubrule { undef }
sub isterminal { 0 }

sub code($$$$)
{
    my ($self, $namespace, $rule) = @_;

'
        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{name} . '},
                      $tracelevel)
                        if defined $::RD_TRACE;
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' ) .'

        $_tok = ($_noactions) ? 0 : do ' . $self->{"code"} . ';
        ' . ($self->{"lookahead"}<0?'if':'unless') . ' (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<'.Parse::RecDescent::_Runtime::_matchtracemessage($self,1).' action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>'.Parse::RecDescent::_Runtime::_matchtracemessage($self).' action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        ' . ($self->{line}>=0 ? '$item{'. $self->{hashname} .'}=$_tok;' : '' ) .'
        ' . ($self->{"lookahead"} ? '$text = $_savetext;' : '' ) .'
'
}


1;

package Parse::RecDescent::_Runtime::Directive;

sub sethashname { $_[0]->{hashname} = '__DIRECTIVE' . ++$_[1]->{dircount} .  '__'; }

sub issubrule { undef }
sub isterminal { 0 }
sub describe { $_[1] ? '' : $_[0]->{name} }

sub new ($$$$$)
{
    my $class = ref($_[0]) || $_[0];
    bless
    {
        "code"      => $_[1],
        "lookahead" => $_[2],
        "line"      => $_[3],
        "name"      => $_[4],
    }, $class;
}

sub code($$$$)
{
    my ($self, $namespace, $rule) = @_;

'
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' ) .'

        Parse::RecDescent::_Runtime::_trace(q{Trying directive: ['
                    . $self->describe . ']},
                    Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{name} . '},
                      $tracelevel)
                        if defined $::RD_TRACE; ' .'
        $_tok = do { ' . $self->{"code"} . ' };
        if (defined($_tok))
        {
            Parse::RecDescent::_Runtime::_trace(q{>>'.Parse::RecDescent::_Runtime::_matchtracemessage($self).' directive<< (return value: [}
                        . $_tok . q{])},
                        Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        else
        {
            Parse::RecDescent::_Runtime::_trace(q{<<'.Parse::RecDescent::_Runtime::_matchtracemessage($self,1).' directive>>},
                        Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        ' . ($self->{"lookahead"} ? '$text = $_savetext and ' : '' ) .'
        last '
        . ($self->{"lookahead"}<0?'if':'unless') . ' defined $_tok;
        push @item, $item{'.$self->{hashname}.'}=$_tok;
        ' . ($self->{"lookahead"} ? '$text = $_savetext;' : '' ) .'
'
}

1;

package Parse::RecDescent::_Runtime::UncondReject;

sub issubrule { undef }
sub isterminal { 0 }
sub describe { $_[1] ? '' : $_[0]->{name} }
sub sethashname { $_[0]->{hashname} = '__DIRECTIVE' . ++$_[1]->{dircount} .  '__'; }

sub new ($$$;$)
{
    my $class = ref($_[0]) || $_[0];
    bless
    {
        "lookahead" => $_[1],
        "line"      => $_[2],
        "name"      => $_[3],
    }, $class;
}

# MARK, YOU MAY WANT TO OPTIMIZE THIS.


sub code($$$$)
{
    my ($self, $namespace, $rule) = @_;

'
        Parse::RecDescent::_Runtime::_trace(q{>>Rejecting production<< (found '
                     . $self->describe . ')},
                     Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{name} . '},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $return;
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' ) .'

        $_tok = undef;
        ' . ($self->{"lookahead"} ? '$text = $_savetext and ' : '' ) .'
        last '
        . ($self->{"lookahead"}<0?'if':'unless') . ' defined $_tok;
'
}

1;

package Parse::RecDescent::_Runtime::Error;

sub issubrule { undef }
sub isterminal { 0 }
sub describe { $_[1] ? '' : $_[0]->{commitonly} ? '<error?:...>' : '<error...>' }
sub sethashname { $_[0]->{hashname} = '__DIRECTIVE' . ++$_[1]->{dircount} .  '__'; }

sub new ($$$$$)
{
    my $class = ref($_[0]) || $_[0];
    bless
    {
        "msg"        => $_[1],
        "lookahead"  => $_[2],
        "commitonly" => $_[3],
        "line"       => $_[4],
    }, $class;
}

sub code($$$$)
{
    my ($self, $namespace, $rule) = @_;

    my $action = '';

    if ($self->{"msg"})  # ERROR MESSAGE SUPPLIED
    {
        #WAS: $action .= "Parse::RecDescent::_Runtime::_error(qq{$self->{msg}}" .  ',$thisline);';
        $action .= 'push @{$thisparser->{errors}}, [qq{'.$self->{msg}.'},$thisline];';

    }
    else      # GENERATE ERROR MESSAGE DURING PARSE
    {
        $action .= '
        my $rule = $item[0];
           $rule =~ s/_/ /g;
        #WAS: Parse::RecDescent::_Runtime::_error("Invalid $rule: " . $expectation->message() ,$thisline);
        push @{$thisparser->{errors}}, ["Invalid $rule: " . $expectation->message() ,$thisline];
        ';
    }

    my $dir =
          new Parse::RecDescent::_Runtime::Directive('if (' .
        ($self->{"commitonly"} ? '$commit' : '1') .
        ") { do {$action} unless ".' $_noactions; undef } else {0}',
                    $self->{"lookahead"},0,$self->describe);
    $dir->{hashname} = $self->{hashname};
    return $dir->code($namespace, $rule, 0);
}

1;

package Parse::RecDescent::_Runtime::Token;

sub sethashname { $_[0]->{hashname} = '__PATTERN' . ++$_[1]->{patcount} . '__'; }

sub issubrule { undef }
sub isterminal { 1 }
sub describe ($) { shift->{'description'}}


# ARGS ARE: $self, $pattern, $left_delim, $modifiers, $lookahead, $linenum
sub new ($$$$$$)
{
    my $class = ref($_[0]) || $_[0];
    my $pattern = $_[1];
    my $pat = $_[1];
    my $ldel = $_[2];
    my $rdel = $ldel;
    $rdel =~ tr/{[(</}])>/;

    my $mod = $_[3];

    my $desc;

    if ($ldel eq '/') { $desc = "$ldel$pattern$rdel$mod" }
    else          { $desc = "m$ldel$pattern$rdel$mod" }
    $desc =~ s/\\/\\\\/g;
    $desc =~ s/\$$/\\\$/g;
    $desc =~ s/}/\\}/g;
    $desc =~ s/{/\\{/g;

    if (!eval "no strict;
           local \$SIG{__WARN__} = sub {0};
           '' =~ m$ldel$pattern$rdel$mod" and $@)
    {
        Parse::RecDescent::_Runtime::_warn(3, "Token pattern \"m$ldel$pattern$rdel$mod\"
                         may not be a valid regular expression",
                       $_[5]);
        $@ =~ s/ at \(eval.*/./;
        Parse::RecDescent::_Runtime::_hint($@);
    }

    # QUIETLY PREVENT (WELL-INTENTIONED) CALAMITY
    $mod =~ s/[gc]//g;
    $pattern =~ s/(\A|[^\\])\\G/$1/g;

    bless
    {
        "pattern"   => $pattern,
        "ldelim"      => $ldel,
        "rdelim"      => $rdel,
        "mod"         => $mod,
        "lookahead"   => $_[4],
        "line"        => $_[5],
        "description" => $desc,
    }, $class;
}


sub code($$$$$)
{
    my ($self, $namespace, $rule, $check) = @_;
    my $ldel = $self->{"ldelim"};
    my $rdel = $self->{"rdelim"};
    my $sdel = $ldel;
    my $mod  = $self->{"mod"};

    $sdel =~ s/[[{(<]/{}/;

my $code = '
        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [' . $self->describe
                      . ']}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{name} . '},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{' . ($rule->hasleftmost($self) ? ''
                : $self->describe ) . '})->at($text);
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' ) . '

        ' . ($self->{"lookahead"}<0?'if':'unless')
        . ' ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and '
        . ($check->{itempos}? 'do {'.Parse::RecDescent::_Runtime::Production::incitempos().' 1} and ' : '')
        . '  $text =~ m' . $ldel . '\A(?:' . $self->{"pattern"} . ')' . $rdel . $mod . ')
        {
            '.($self->{"lookahead"} ? '$text = $_savetext;' : '$text = $lastsep . $text if defined $lastsep;') .
            ($check->{itempos} ? Parse::RecDescent::_Runtime::Production::unincitempos() : '') . '
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn\'t match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{'.$self->{hashname}.'}=$current_match;
        ' . ($self->{"lookahead"} ? '$text = $_savetext;' : '' ) .'
';

    return $code;
}

1;

package Parse::RecDescent::_Runtime::Literal;

sub sethashname { $_[0]->{hashname} = '__STRING' . ++$_[1]->{strcount} . '__'; }

sub issubrule { undef }
sub isterminal { 1 }
sub describe ($) { shift->{'description'} }

sub new ($$$$)
{
    my $class = ref($_[0]) || $_[0];

    my $pattern = $_[1];

    my $desc = $pattern;
    $desc=~s/\\/\\\\/g;
    $desc=~s/}/\\}/g;
    $desc=~s/{/\\{/g;

    bless
    {
        "pattern"     => $pattern,
        "lookahead"   => $_[2],
        "line"        => $_[3],
        "description" => "'$desc'",
    }, $class;
}


sub code($$$$)
{
    my ($self, $namespace, $rule, $check) = @_;

my $code = '
        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [' . $self->describe
                      . ']},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{name} . '},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{' . ($rule->hasleftmost($self) ? ''
                : $self->describe ) . '})->at($text);
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' ) . '

        ' . ($self->{"lookahead"}<0?'if':'unless')
        . ' ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and '
        . ($check->{itempos}? 'do {'.Parse::RecDescent::_Runtime::Production::incitempos().' 1} and ' : '')
        . '  $text =~ m/\A' . quotemeta($self->{"pattern"}) . '/)
        {
            '.($self->{"lookahead"} ? '$text = $_savetext;' : '$text = $lastsep . $text if defined $lastsep;').'
            '. ($check->{itempos} ? Parse::RecDescent::_Runtime::Production::unincitempos() : '') . '
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(qq{<<Didn\'t match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{'.$self->{hashname}.'}=$current_match;
        ' . ($self->{"lookahead"} ? '$text = $_savetext;' : '' ) .'
';

    return $code;
}

1;

package Parse::RecDescent::_Runtime::InterpLit;

sub sethashname { $_[0]->{hashname} = '__STRING' . ++$_[1]->{strcount} . '__'; }

sub issubrule { undef }
sub isterminal { 1 }
sub describe ($) { shift->{'description'} }

sub new ($$$$)
{
    my $class = ref($_[0]) || $_[0];

    my $pattern = $_[1];
    $pattern =~ s#/#\\/#g;

    my $desc = $pattern;
    $desc=~s/\\/\\\\/g;
    $desc=~s/}/\\}/g;
    $desc=~s/{/\\{/g;

    bless
    {
        "pattern"   => $pattern,
        "lookahead" => $_[2],
        "line"      => $_[3],
        "description" => "'$desc'",
    }, $class;
}

sub code($$$$)
{
    my ($self, $namespace, $rule, $check) = @_;

my $code = '
        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [' . $self->describe
                      . ']},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{name} . '},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{' . ($rule->hasleftmost($self) ? ''
                : $self->describe ) . '})->at($text);
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' ) . '

        ' . ($self->{"lookahead"}<0?'if':'unless')
        . ' ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and '
        . ($check->{itempos}? 'do {'.Parse::RecDescent::_Runtime::Production::incitempos().' 1} and ' : '')
        . '  do { $_tok = "' . $self->{"pattern"} . '"; 1 } and
             substr($text,0,length($_tok)) eq $_tok and
             do { substr($text,0,length($_tok)) = ""; 1; }
        )
        {
            '.($self->{"lookahead"} ? '$text = $_savetext;' : '$text = $lastsep . $text if defined $lastsep;').'
            '. ($check->{itempos} ? Parse::RecDescent::_Runtime::Production::unincitempos() : '') . '
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn\'t match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $_tok . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{'.$self->{hashname}.'}=$_tok;
        ' . ($self->{"lookahead"} ? '$text = $_savetext;' : '' ) .'
';

    return $code;
}

1;

package Parse::RecDescent::_Runtime::Subrule;

sub issubrule ($) { return $_[0]->{"subrule"} }
sub isterminal { 0 }
sub sethashname {}

sub describe ($)
{
    my $desc = $_[0]->{"implicit"} || $_[0]->{"subrule"};
    $desc = "<matchrule:$desc>" if $_[0]->{"matchrule"};
    return $desc;
}

sub callsyntax($$)
{
    if ($_[0]->{"matchrule"})
    {
        return "&{'$_[1]'.qq{$_[0]->{subrule}}}";
    }
    else
    {
        return $_[1].$_[0]->{"subrule"};
    }
}

sub new ($$$$;$$$)
{
    my $class = ref($_[0]) || $_[0];
    bless
    {
        "subrule"   => $_[1],
        "lookahead" => $_[2],
        "line"      => $_[3],
        "implicit"  => $_[4] || undef,
        "matchrule" => $_[5],
        "argcode"   => $_[6] || undef,
    }, $class;
}


sub code($$$$)
{
    my ($self, $namespace, $rule, $check) = @_;

'
        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [' . $self->{"subrule"} . ']},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{' . $rule->{"name"} . '},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(' . ($rule->hasleftmost($self) ? 'q{}'
                # WAS : 'qq{'.$self->describe.'}' ) . ')->at($text);
                : 'q{'.$self->describe.'}' ) . ')->at($text);
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' )
        . ($self->{"lookahead"}<0?'if':'unless')
        . ' (defined ($_tok = '
        . $self->callsyntax($namespace.'::')
        . '($thisparser,$text,$repeating,'
        . ($self->{"lookahead"}?'1':'$_noactions')
        . ($self->{argcode} ? ",sub { return $self->{argcode} }"
                   : ',sub { \\@arg }')
        . ($check->{"itempos"}?',$itempos[$#itempos]':',undef')
        . ')))
        {
            '.($self->{"lookahead"} ? '$text = $_savetext;' : '').'
            Parse::RecDescent::_Runtime::_trace(q{<<'.Parse::RecDescent::_Runtime::_matchtracemessage($self,1).' subrule: ['
            . $self->{subrule} . ']>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{' . $rule->{"name"} .'},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>'.Parse::RecDescent::_Runtime::_matchtracemessage($self).' subrule: ['
                    . $self->{subrule} . ']<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{"name"} .'},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{' . $self->{subrule} . '}} = $_tok;
        push @item, $_tok;
        ' . ($self->{"lookahead"} ? '$text = $_savetext;' : '' ) .'
        }
'
}

package Parse::RecDescent::_Runtime::Repetition;

sub issubrule ($) { return $_[0]->{"subrule"} }
sub isterminal { 0 }
sub sethashname {  }

sub describe ($)
{
    my $desc = $_[0]->{"expected"} || $_[0]->{"subrule"};
    $desc = "<matchrule:$desc>" if $_[0]->{"matchrule"};
    return $desc;
}

sub callsyntax($$)
{
    if ($_[0]->{matchrule})
        { return "sub { goto &{''.qq{$_[1]$_[0]->{subrule}}} }"; }
    else
        { return "\\&$_[1]$_[0]->{subrule}"; }
}

sub new ($$$$$$$$$$)
{
    my ($self, $subrule, $repspec, $min, $max, $lookahead, $line, $parser, $matchrule, $argcode) = @_;
    my $class = ref($self) || $self;
    ($max, $min) = ( $min, $max) if ($max<$min);

    my $desc;
    if ($subrule=~/\A_alternation_\d+_of_production_\d+_of_rule/)
        { $desc = $parser->{"rules"}{$subrule}->expected }

    if ($lookahead)
    {
        if ($min>0)
        {
           return new Parse::RecDescent::_Runtime::Subrule($subrule,$lookahead,$line,$desc,$matchrule,$argcode);
        }
        else
        {
            Parse::RecDescent::_Runtime::_error("Not symbol (\"!\") before
                        \"$subrule\" doesn't make
                        sense.",$line);
            Parse::RecDescent::_Runtime::_hint("Lookahead for negated optional
                       repetitions (such as
                       \"!$subrule($repspec)\" can never
                       succeed, since optional items always
                       match (zero times at worst).
                       Did you mean a single \"!$subrule\",
                       instead?");
        }
    }
    bless
    {
        "subrule"   => $subrule,
        "repspec"   => $repspec,
        "min"       => $min,
        "max"       => $max,
        "lookahead" => $lookahead,
        "line"      => $line,
        "expected"  => $desc,
        "argcode"   => $argcode || undef,
        "matchrule" => $matchrule,
    }, $class;
}

sub code($$$$)
{
    my ($self, $namespace, $rule, $check) = @_;

    my ($subrule, $repspec, $min, $max, $lookahead) =
        @{$self}{ qw{subrule repspec min max lookahead} };

'
        Parse::RecDescent::_Runtime::_trace(q{Trying repeated subrule: [' . $self->describe . ']},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{' . $rule->{"name"} . '},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(' . ($rule->hasleftmost($self) ? 'q{}'
                # WAS : 'qq{'.$self->describe.'}' ) . ')->at($text);
                : 'q{'.$self->describe.'}' ) . ')->at($text);
        ' . ($self->{"lookahead"} ? '$_savetext = $text;' : '' ) .'
        unless (defined ($_tok = $thisparser->_parserepeat($text, '
        . $self->callsyntax($namespace.'::')
        . ', ' . $min . ', ' . $max . ', '
        . ($self->{"lookahead"}?'1':'$_noactions')
        . ',$expectation,'
        . ($self->{argcode} ? "sub { return $self->{argcode} }"
                        : 'sub { \\@arg }')
        . ($check->{"itempos"}?',$itempos[$#itempos]':',undef')
        . ')))
        {
            Parse::RecDescent::_Runtime::_trace(q{<<'.Parse::RecDescent::_Runtime::_matchtracemessage($self,1).' repeated subrule: ['
            . $self->describe . ']>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{' . $rule->{"name"} .'},
                          $tracelevel)
                            if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>'.Parse::RecDescent::_Runtime::_matchtracemessage($self).' repeated subrule: ['
                    . $self->{subrule} . ']<< (}
                    . @$_tok . q{ times)},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{"name"} .'},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{' . "$self->{subrule}($self->{repspec})" . '}} = $_tok;
        push @item, $_tok;
        ' . ($self->{"lookahead"} ? '$text = $_savetext;' : '' ) .'

'
}

package Parse::RecDescent::_Runtime::Result;

sub issubrule { 0 }
sub isterminal { 0 }
sub describe { '' }

sub new
{
    my ($class, $pos) = @_;

    bless {}, $class;
}

sub code($$$$)
{
    my ($self, $namespace, $rule) = @_;

    '
        $return = $item[-1];
    ';
}

package Parse::RecDescent::_Runtime::Operator;

my @opertype = ( " non-optional", "n optional" );

sub issubrule { 0 }
sub isterminal { 0 }

sub describe { $_[0]->{"expected"} }
sub sethashname { $_[0]->{hashname} = '__DIRECTIVE' . ++$_[1]->{dircount} .  '__'; }


sub new
{
    my ($class, $type, $minrep, $maxrep, $leftarg, $op, $rightarg) = @_;

    bless
    {
        "type"      => "${type}op",
        "leftarg"   => $leftarg,
        "op"        => $op,
        "min"       => $minrep,
        "max"       => $maxrep,
        "rightarg"  => $rightarg,
        "expected"  => "<${type}op: ".$leftarg->describe." ".$op->describe." ".$rightarg->describe.">",
    }, $class;
}

sub code($$$$)
{
    my ($self, $namespace, $rule, $check) = @_;

    my @codeargs = @_[1..$#_];

    my ($leftarg, $op, $rightarg) =
        @{$self}{ qw{leftarg op rightarg} };

    my $code = '
        Parse::RecDescent::_Runtime::_trace(q{Trying operator: [' . $self->describe . ']},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{' . $rule->{"name"} . '},
                  $tracelevel)
                    if defined $::RD_TRACE;
        $expectation->is(' . ($rule->hasleftmost($self) ? 'q{}'
                # WAS : 'qq{'.$self->describe.'}' ) . ')->at($text);
                : 'q{'.$self->describe.'}' ) . ')->at($text);

        $_tok = undef;
        OPLOOP: while (1)
        {
          $repcount = 0;
          my @item;
          my %item;
';

    $code .= '
          my  $_itempos = $itempos[-1];
          my  $itemposfirst;
' if $check->{itempos};

    if ($self->{type} eq "leftop" )
    {
        $code .= '
          # MATCH LEFTARG
          ' . $leftarg->code(@codeargs) . '

';

        $code .= '
          if (defined($_itempos) and !defined($itemposfirst))
          {
              $itemposfirst = Parse::RecDescent::_Runtime::Production::_duplicate_itempos($_itempos);
          }
' if $check->{itempos};

        $code .= '
          $repcount++;

          my $savetext = $text;
          my $backtrack;

          # MATCH (OP RIGHTARG)(s)
          while ($repcount < ' . $self->{max} . ')
          {
            $backtrack = 0;
            ' . $op->code(@codeargs) . '
            ' . ($op->isterminal() ? 'pop @item;' : '$backtrack=1;' ) . '
            ' . (ref($op) eq 'Parse::RecDescent::_Runtime::Token'
                ? 'if (defined $1) {push @item, $item{'.($self->{name}||$self->{hashname}).'}=$1; $backtrack=1;}'
                : "" ) . '
            ' . $rightarg->code(@codeargs) . '
            $savetext = $text;
            $repcount++;
          }
          $text = $savetext;
          pop @item if $backtrack;

          ';
    }
    else
    {
        $code .= '
          my $savetext = $text;
          my $backtrack;
          # MATCH (LEFTARG OP)(s)
          while ($repcount < ' . $self->{max} . ')
          {
            $backtrack = 0;
            ' . $leftarg->code(@codeargs) . '
';
        $code .= '
            if (defined($_itempos) and !defined($itemposfirst))
            {
                $itemposfirst = Parse::RecDescent::_Runtime::Production::_duplicate_itempos($_itempos);
            }
' if $check->{itempos};

        $code .= '
            $repcount++;
            $backtrack = 1;
            ' . $op->code(@codeargs) . '
            $savetext = $text;
            ' . ($op->isterminal() ? 'pop @item;' : "" ) . '
            ' . (ref($op) eq 'Parse::RecDescent::_Runtime::Token' ? 'do { push @item, $item{'.($self->{name}||$self->{hashname}).'}=$1; } if defined $1;' : "" ) . '
          }
          $text = $savetext;
          pop @item if $backtrack;

          # MATCH RIGHTARG
          ' . $rightarg->code(@codeargs) . '
          $repcount++;
          ';
    }

    $code .= 'unless (@item) { undef $_tok; last }' unless $self->{min}==0;

    $code .= '
          $_tok = [ @item ];
';


    $code .= '
          if (defined $itemposfirst)
          {
              Parse::RecDescent::_Runtime::Production::_update_itempos(
                  $_itempos, $itemposfirst, undef, [qw(from)]);
          }
' if $check->{itempos};

    $code .= '
          last;
        } # end of OPLOOP
';

    $code .= '
        unless ($repcount>='.$self->{min}.')
        {
            Parse::RecDescent::_Runtime::_trace(q{<<'.Parse::RecDescent::_Runtime::_matchtracemessage($self,1).' operator: ['
                          . $self->describe
                          . ']>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{' . $rule->{"name"} .'},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>'.Parse::RecDescent::_Runtime::_matchtracemessage($self).' operator: ['
                      . $self->describe
                      . ']<< (return value: [}
                      . qq{@{$_tok||[]}} . q{]},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{' . $rule->{"name"} .'},
                      $tracelevel)
                        if defined $::RD_TRACE;

        push @item, $item{'.($self->{name}||$self->{hashname}).'}=$_tok||[];
';

    return $code;
}


package Parse::RecDescent::_Runtime::Expectation;

sub new ($)
{
    bless {
        "failed"      => 0,
        "expected"    => "",
        "unexpected"      => "",
        "lastexpected"    => "",
        "lastunexpected"  => "",
        "defexpected"     => $_[1],
          };
}

sub is ($$)
{
    $_[0]->{lastexpected} = $_[1]; return $_[0];
}

sub at ($$)
{
    $_[0]->{lastunexpected} = $_[1]; return $_[0];
}

sub failed ($)
{
    return unless $_[0]->{lastexpected};
    $_[0]->{expected}   = $_[0]->{lastexpected}   unless $_[0]->{failed};
    $_[0]->{unexpected} = $_[0]->{lastunexpected} unless $_[0]->{failed};
    $_[0]->{failed} = 1;
}

sub message ($)
{
    my ($self) = @_;
    $self->{expected} = $self->{defexpected} unless $self->{expected};
    $self->{expected} =~ s/_/ /g;
    if (!$self->{unexpected} || $self->{unexpected} =~ /\A\s*\Z/s)
    {
        return "Was expecting $self->{expected}";
    }
    else
    {
        $self->{unexpected} =~ /\s*(.*)/;
        return "Was expecting $self->{expected} but found \"$1\" instead";
    }
}

1;

package Parse::RecDescent::_Runtime;

use Carp;
use vars qw ( $AUTOLOAD $VERSION $_FILENAME);

my $ERRORS = 0;

our $VERSION = '1.967009';
$VERSION = eval $VERSION;
$_FILENAME=__FILE__;

# BUILDING A PARSER

my $nextnamespace = "namespace000001";

sub _nextnamespace()
{
    return "Parse::RecDescent::_Runtime::" . $nextnamespace++;
}

# ARGS ARE: $class, $grammar, $compiling, $namespace
sub new ($$$$)
{
    my $class = ref($_[0]) || $_[0];
    local $Parse::RecDescent::_Runtime::compiling = $_[2];
    my $name_space_name = defined $_[3]
        ? "Parse::RecDescent::_Runtime::".$_[3]
        : _nextnamespace();
    my $self =
    {
        "rules"     => {},
        "namespace" => $name_space_name,
        "startcode" => '',
        "localvars" => '',
        "_AUTOACTION" => undef,
        "_AUTOTREE"   => undef,

        # Precompiled parsers used to set _precompiled, but that
        # wasn't present in some versions of Parse::RecDescent::_Runtime used to
        # build precompiled parsers.  Instead, set a new
        # _not_precompiled flag, which is remove from future
        # Precompiled parsers at build time.
        "_not_precompiled" => 1,
    };


    if ($::RD_AUTOACTION) {
        my $sourcecode = $::RD_AUTOACTION;
        $sourcecode = "{ $sourcecode }"
            unless $sourcecode =~ /\A\s*\{.*\}\s*\Z/;
        $self->{_check}{itempos} =
            $sourcecode =~ /\@itempos\b|\$itempos\s*\[/;
        $self->{_AUTOACTION}
            = new Parse::RecDescent::_Runtime::Action($sourcecode,0,-1)
    }

    bless $self, $class;
    return $self->Replace($_[1])
}

sub Compile($$$$) {
    die "Compilation of Parse::RecDescent::_Runtime grammars not yet implemented\n";
}

sub DESTROY {
    my ($self) = @_;
    my $namespace = $self->{namespace};
    $namespace =~ s/Parse::RecDescent::_Runtime:://;
    if ($self->{_not_precompiled}) {
        # BEGIN WORKAROUND
        # Perl has a bug that creates a circular reference between
        # @ISA and that variable's stash:
        #   https://rt.perl.org/rt3/Ticket/Display.html?id=92708
        # Emptying the array before deleting the stash seems to
        # prevent the leak.  Once the ticket above has been resolved,
        # these two lines can be removed.
        no strict 'refs';
        @{$self->{namespace} . '::ISA'} = ();
        # END WORKAROUND

        # Some grammars may contain circular references between rules,
        # such as:
        #   a: 'ID' | b
        #   b: '(' a ')'
        # Unless these references are broken, the subs stay around on
        # stash deletion below.  Iterate through the stash entries and
        # for each defined code reference, set it to reference sub {}
        # instead.
        {
            local $^W; # avoid 'sub redefined' warnings.
            my $blank_sub = sub {};
            while (my ($name, $glob) = each %{"Parse::RecDescent::_Runtime::$namespace\::"}) {
                *$glob = $blank_sub if defined &$glob;
            }
        }

        # Delete the namespace's stash
        delete $Parse::RecDescent::_Runtime::{$namespace.'::'};
    }
}

# BUILDING A GRAMMAR....

# ARGS ARE: $self, $grammar, $isimplicit, $isleftop
sub Replace ($$)
{
    # set $replace = 1 for _generate
    splice(@_, 2, 0, 1);

    return _generate(@_);
}

# ARGS ARE: $self, $grammar, $isimplicit, $isleftop
sub Extend ($$)
{
    # set $replace = 0 for _generate
    splice(@_, 2, 0, 0);

    return _generate(@_);
}

sub _no_rule ($$;$)
{
    _error("Ruleless $_[0] at start of grammar.",$_[1]);
    my $desc = $_[2] ? "\"$_[2]\"" : "";
    _hint("You need to define a rule for the $_[0] $desc
           to be part of.");
}

my $NEGLOOKAHEAD    = '\G(\s*\.\.\.\!)';
my $POSLOOKAHEAD    = '\G(\s*\.\.\.)';
my $RULE        = '\G\s*(\w+)[ \t]*:';
my $PROD        = '\G\s*([|])';
my $TOKEN       = q{\G\s*/((\\\\/|\\\\\\\\|[^/])*)/([cgimsox]*)};
my $MTOKEN      = q{\G\s*(m\s*[^\w\s])};
my $LITERAL     = q{\G\s*'((\\\\['\\\\]|[^'])*)'};
my $INTERPLIT       = q{\G\s*"((\\\\["\\\\]|[^"])*)"};
my $SUBRULE     = '\G\s*(\w+)';
my $MATCHRULE       = '\G(\s*<matchrule:)';
my $SIMPLEPAT       = '((\\s+/[^/\\\\]*(?:\\\\.[^/\\\\]*)*/)?)';
my $OPTIONAL        = '\G\((\?)'.$SIMPLEPAT.'\)';
my $ANY         = '\G\((s\?)'.$SIMPLEPAT.'\)';
my $MANY        = '\G\((s|\.\.)'.$SIMPLEPAT.'\)';
my $EXACTLY     = '\G\(([1-9]\d*)'.$SIMPLEPAT.'\)';
my $BETWEEN     = '\G\((\d+)\.\.([1-9]\d*)'.$SIMPLEPAT.'\)';
my $ATLEAST     = '\G\((\d+)\.\.'.$SIMPLEPAT.'\)';
my $ATMOST      = '\G\(\.\.([1-9]\d*)'.$SIMPLEPAT.'\)';
my $BADREP      = '\G\((-?\d+)?\.\.(-?\d+)?'.$SIMPLEPAT.'\)';
my $ACTION      = '\G\s*\{';
my $IMPLICITSUBRULE = '\G\s*\(';
my $COMMENT     = '\G\s*(#.*)';
my $COMMITMK        = '\G\s*<commit>';
my $UNCOMMITMK      = '\G\s*<uncommit>';
my $QUOTELIKEMK     = '\G\s*<perl_quotelike>';
my $CODEBLOCKMK     = '\G\s*<perl_codeblock(?:\s+([][()<>{}]+))?>';
my $VARIABLEMK      = '\G\s*<perl_variable>';
my $NOCHECKMK       = '\G\s*<nocheck>';
my $AUTOACTIONPATMK = '\G\s*<autoaction:';
my $AUTOTREEMK      = '\G\s*<autotree(?::\s*([\w:]+)\s*)?>';
my $AUTOSTUBMK      = '\G\s*<autostub>';
my $AUTORULEMK      = '\G\s*<autorule:(.*?)>';
my $REJECTMK        = '\G\s*<reject>';
my $CONDREJECTMK    = '\G\s*<reject:';
my $SCOREMK     = '\G\s*<score:';
my $AUTOSCOREMK     = '\G\s*<autoscore:';
my $SKIPMK      = '\G\s*<skip:';
my $OPMK        = '\G\s*<(left|right)op(?:=(\'.*?\'))?:';
my $ENDDIRECTIVEMK  = '\G\s*>';
my $RESYNCMK        = '\G\s*<resync>';
my $RESYNCPATMK     = '\G\s*<resync:';
my $RULEVARPATMK    = '\G\s*<rulevar:';
my $DEFERPATMK      = '\G\s*<defer:';
my $TOKENPATMK      = '\G\s*<token:';
my $AUTOERRORMK     = '\G\s*<error(\??)>';
my $MSGERRORMK      = '\G\s*<error(\??):';
my $NOCHECK     = '\G\s*<nocheck>';
my $WARNMK      = '\G\s*<warn((?::\s*(\d+)\s*)?)>';
my $HINTMK      = '\G\s*<hint>';
my $TRACEBUILDMK    = '\G\s*<trace_build((?::\s*(\d+)\s*)?)>';
my $TRACEPARSEMK    = '\G\s*<trace_parse((?::\s*(\d+)\s*)?)>';
my $UNCOMMITPROD    = $PROD.'\s*<uncommit';
my $ERRORPROD       = $PROD.'\s*<error';
my $LONECOLON       = '\G\s*:';
my $OTHER       = '\G\s*([^\s]+)';

my @lines = 0;

sub _generate
{
    my ($self, $grammar, $replace, $isimplicit, $isleftop) = (@_, 0);

    my $aftererror = 0;
    my $lookahead = 0;
    my $lookaheadspec = "";
    my $must_pop_lines;
    if (! $lines[-1]) {
        push @lines, _linecount($grammar) ;
        $must_pop_lines = 1;
    }
    $self->{_check}{itempos} = ($grammar =~ /\@itempos\b|\$itempos\s*\[/)
        unless $self->{_check}{itempos};
    for (qw(thisoffset thiscolumn prevline prevoffset prevcolumn))
    {
        $self->{_check}{$_} =
            ($grammar =~ /\$$_/) || $self->{_check}{itempos}
                unless $self->{_check}{$_};
    }
    my $line;

    my $rule = undef;
    my $prod = undef;
    my $item = undef;
    my $lastgreedy = '';
    pos $grammar = 0;
    study $grammar;

    local $::RD_HINT  = $::RD_HINT;
    local $::RD_WARN  = $::RD_WARN;
    local $::RD_TRACE = $::RD_TRACE;
    local $::RD_CHECK = $::RD_CHECK;

    while (pos $grammar < length $grammar)
    {
        $line = $lines[-1] - _linecount($grammar) + 1;
        my $commitonly;
        my $code = "";
        my @components = ();
        if ($grammar =~ m/$COMMENT/gco)
        {
            _parse("a comment",0,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
            next;
        }
        elsif ($grammar =~ m/$NEGLOOKAHEAD/gco)
        {
            _parse("a negative lookahead",$aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
            $lookahead = $lookahead ? -$lookahead : -1;
            $lookaheadspec .= $1;
            next;   # SKIP LOOKAHEAD RESET AT END OF while LOOP
        }
        elsif ($grammar =~ m/$POSLOOKAHEAD/gco)
        {
            _parse("a positive lookahead",$aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
            $lookahead = $lookahead ? $lookahead : 1;
            $lookaheadspec .= $1;
            next;   # SKIP LOOKAHEAD RESET AT END OF while LOOP
        }
        elsif ($grammar =~ m/(?=$ACTION)/gco
            and do { ($code) = extract_codeblock($grammar); $code })
        {
            _parse("an action", $aftererror, $line, $code);
            $item = new Parse::RecDescent::_Runtime::Action($code,$lookahead,$line);
            $prod and $prod->additem($item)
                  or  $self->_addstartcode($code);
        }
        elsif ($grammar =~ m/(?=$IMPLICITSUBRULE)/gco
            and do { ($code) = extract_codeblock($grammar,'{([',undef,'(',1);
                $code })
        {
            $code =~ s/\A\s*\(|\)\Z//g;
            _parse("an implicit subrule", $aftererror, $line,
                "( $code )");
            my $implicit = $rule->nextimplicit;
            return undef
                if !$self->_generate("$implicit : $code",$replace,1);
            my $pos = pos $grammar;
            substr($grammar,$pos,0,$implicit);
            pos $grammar = $pos;;
        }
        elsif ($grammar =~ m/$ENDDIRECTIVEMK/gco)
        {

        # EXTRACT TRAILING REPETITION SPECIFIER (IF ANY)

            my ($minrep,$maxrep) = (1,$MAXREP);
            if ($grammar =~ m/\G[(]/gc)
            {
                pos($grammar)--;

                if ($grammar =~ m/$OPTIONAL/gco)
                    { ($minrep, $maxrep) = (0,1) }
                elsif ($grammar =~ m/$ANY/gco)
                    { $minrep = 0 }
                elsif ($grammar =~ m/$EXACTLY/gco)
                    { ($minrep, $maxrep) = ($1,$1) }
                elsif ($grammar =~ m/$BETWEEN/gco)
                    { ($minrep, $maxrep) = ($1,$2) }
                elsif ($grammar =~ m/$ATLEAST/gco)
                    { $minrep = $1 }
                elsif ($grammar =~ m/$ATMOST/gco)
                    { $maxrep = $1 }
                elsif ($grammar =~ m/$MANY/gco)
                    { }
                elsif ($grammar =~ m/$BADREP/gco)
                {
                    _parse("an invalid repetition specifier", 0,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                    _error("Incorrect specification of a repeated directive",
                           $line);
                    _hint("Repeated directives cannot have
                           a maximum repetition of zero, nor can they have
                           negative components in their ranges.");
                }
            }

            $prod && $prod->enddirective($line,$minrep,$maxrep);
        }
        elsif ($grammar =~ m/\G\s*<[^m]/gc)
        {
            pos($grammar)-=2;

            if ($grammar =~ m/$OPMK/gco)
            {
                # $DB::single=1;
                _parse("a $1-associative operator directive", $aftererror, $line, "<$1op:...>");
                $prod->adddirective($1, $line,$2||'');
            }
            elsif ($grammar =~ m/$UNCOMMITMK/gco)
            {
                _parse("an uncommit marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::Directive('$commit=0;1',
                                  $lookahead,$line,"<uncommit>");
                $prod and $prod->additem($item)
                      or  _no_rule("<uncommit>",$line);
            }
            elsif ($grammar =~ m/$QUOTELIKEMK/gco)
            {
                _parse("an perl quotelike marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::Directive(
                    'my ($match,@res);
                     ($match,$text,undef,@res) =
                          Text::Balanced::extract_quotelike($text,$skip);
                      $match ? \@res : undef;
                    ', $lookahead,$line,"<perl_quotelike>");
                $prod and $prod->additem($item)
                      or  _no_rule("<perl_quotelike>",$line);
            }
            elsif ($grammar =~ m/$CODEBLOCKMK/gco)
            {
                my $outer = $1||"{}";
                _parse("an perl codeblock marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::Directive(
                    'Text::Balanced::extract_codeblock($text,undef,$skip,\''.$outer.'\');
                    ', $lookahead,$line,"<perl_codeblock>");
                $prod and $prod->additem($item)
                      or  _no_rule("<perl_codeblock>",$line);
            }
            elsif ($grammar =~ m/$VARIABLEMK/gco)
            {
                _parse("an perl variable marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::Directive(
                    'Text::Balanced::extract_variable($text,$skip);
                    ', $lookahead,$line,"<perl_variable>");
                $prod and $prod->additem($item)
                      or  _no_rule("<perl_variable>",$line);
            }
            elsif ($grammar =~ m/$NOCHECKMK/gco)
            {
                _parse("a disable checking marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                if ($rule)
                {
                    _error("<nocheck> directive not at start of grammar", $line);
                    _hint("The <nocheck> directive can only
                           be specified at the start of a
                           grammar (before the first rule
                           is defined.");
                }
                else
                {
                    local $::RD_CHECK = 1;
                }
            }
            elsif ($grammar =~ m/$AUTOSTUBMK/gco)
            {
                _parse("an autostub marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $::RD_AUTOSTUB = "";
            }
            elsif ($grammar =~ m/$AUTORULEMK/gco)
            {
                _parse("an autorule marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $::RD_AUTOSTUB = $1;
            }
            elsif ($grammar =~ m/$AUTOTREEMK/gco)
            {
                my $base = defined($1) ? $1 : "";
                my $current_match = substr($grammar, $-[0], $+[0] - $-[0]);
                $base .= "::" if $base && $base !~ /::$/;
                _parse("an autotree marker", $aftererror,$line, $current_match);
                if ($rule)
                {
                    _error("<autotree> directive not at start of grammar", $line);
                    _hint("The <autotree> directive can only
                           be specified at the start of a
                           grammar (before the first rule
                           is defined.");
                }
                else
                {
                    undef $self->{_AUTOACTION};
                    $self->{_AUTOTREE}{NODE}
                        = new Parse::RecDescent::_Runtime::Action(q({bless \%item, ').$base.q('.$item[0]}),0,-1);
                    $self->{_AUTOTREE}{TERMINAL}
                        = new Parse::RecDescent::_Runtime::Action(q({bless {__VALUE__=>$item[1]}, ').$base.q('.$item[0]}),0,-1);
                }
            }

            elsif ($grammar =~ m/$REJECTMK/gco)
            {
                _parse("an reject marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::UncondReject($lookahead,$line,"<reject>");
                $prod and $prod->additem($item)
                      or  _no_rule("<reject>",$line);
            }
            elsif ($grammar =~ m/(?=$CONDREJECTMK)/gco
                and do { ($code) = extract_codeblock($grammar,'{',undef,'<');
                      $code })
            {
                _parse("a (conditional) reject marker", $aftererror,$line, $code );
                $code =~ /\A\s*<reject:(.*)>\Z/s;
                my $cond = $1;
                $item = new Parse::RecDescent::_Runtime::Directive(
                          "($1) ? undef : 1", $lookahead,$line,"<reject:$cond>");
                $prod and $prod->additem($item)
                      or  _no_rule("<reject:$cond>",$line);
            }
            elsif ($grammar =~ m/(?=$SCOREMK)/gco
                and do { ($code) = extract_codeblock($grammar,'{',undef,'<');
                      $code })
            {
                _parse("a score marker", $aftererror,$line, $code );
                $code =~ /\A\s*<score:(.*)>\Z/s;
                $prod and $prod->addscore($1, $lookahead, $line)
                      or  _no_rule($code,$line);
            }
            elsif ($grammar =~ m/(?=$AUTOSCOREMK)/gco
                and do { ($code) = extract_codeblock($grammar,'{',undef,'<');
                     $code;
                       } )
            {
                _parse("an autoscore specifier", $aftererror,$line,$code);
                $code =~ /\A\s*<autoscore:(.*)>\Z/s;

                $rule and $rule->addautoscore($1,$self)
                      or  _no_rule($code,$line);

                $item = new Parse::RecDescent::_Runtime::UncondReject($lookahead,$line,$code);
                $prod and $prod->additem($item)
                      or  _no_rule($code,$line);
            }
            elsif ($grammar =~ m/$RESYNCMK/gco)
            {
                _parse("a resync to newline marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::Directive(
                          'if ($text =~ s/(\A[^\n]*\n)//) { $return = 0; $1; } else { undef }',
                          $lookahead,$line,"<resync>");
                $prod and $prod->additem($item)
                      or  _no_rule("<resync>",$line);
            }
            elsif ($grammar =~ m/(?=$RESYNCPATMK)/gco
                and do { ($code) = extract_bracketed($grammar,'<');
                      $code })
            {
                _parse("a resync with pattern marker", $aftererror,$line, $code );
                $code =~ /\A\s*<resync:(.*)>\Z/s;
                $item = new Parse::RecDescent::_Runtime::Directive(
                          'if ($text =~ s/(\A'.$1.')//) { $return = 0; $1; } else { undef }',
                          $lookahead,$line,$code);
                $prod and $prod->additem($item)
                      or  _no_rule($code,$line);
            }
            elsif ($grammar =~ m/(?=$SKIPMK)/gco
                and do { ($code) = extract_codeblock($grammar,'<');
                      $code })
            {
                _parse("a skip marker", $aftererror,$line, $code );
                $code =~ /\A\s*<skip:(.*)>\Z/s;
                if ($rule) {
                    $item = new Parse::RecDescent::_Runtime::Directive(
                        'my $oldskip = $skip; $skip='.$1.'; $oldskip',
                        $lookahead,$line,$code);
                    $prod and $prod->additem($item)
                      or  _no_rule($code,$line);
                } else {
                    #global <skip> directive
                    $self->{skip} = $1;
                }
            }
            elsif ($grammar =~ m/(?=$RULEVARPATMK)/gco
                and do { ($code) = extract_codeblock($grammar,'{',undef,'<');
                     $code;
                       } )
            {
                _parse("a rule variable specifier", $aftererror,$line,$code);
                $code =~ /\A\s*<rulevar:(.*)>\Z/s;

                $rule and $rule->addvar($1,$self)
                      or  _no_rule($code,$line);

                $item = new Parse::RecDescent::_Runtime::UncondReject($lookahead,$line,$code);
                $prod and $prod->additem($item)
                      or  _no_rule($code,$line);
            }
            elsif ($grammar =~ m/(?=$AUTOACTIONPATMK)/gco
                and do { ($code) = extract_codeblock($grammar,'{',undef,'<');
                     $code;
                       } )
            {
                _parse("an autoaction specifier", $aftererror,$line,$code);
                $code =~ s/\A\s*<autoaction:(.*)>\Z/$1/s;
                if ($code =~ /\A\s*[^{]|[^}]\s*\Z/) {
                    $code = "{ $code }"
                }
        $self->{_check}{itempos} =
            $code =~ /\@itempos\b|\$itempos\s*\[/;
        $self->{_AUTOACTION}
            = new Parse::RecDescent::_Runtime::Action($code,0,-$line)
            }
            elsif ($grammar =~ m/(?=$DEFERPATMK)/gco
                and do { ($code) = extract_codeblock($grammar,'{',undef,'<');
                     $code;
                       } )
            {
                _parse("a deferred action specifier", $aftererror,$line,$code);
                $code =~ s/\A\s*<defer:(.*)>\Z/$1/s;
                if ($code =~ /\A\s*[^{]|[^}]\s*\Z/)
                {
                    $code = "{ $code }"
                }

                $item = new Parse::RecDescent::_Runtime::Directive(
                          "push \@{\$thisparser->{deferred}}, sub $code;",
                          $lookahead,$line,"<defer:$code>");
                $prod and $prod->additem($item)
                      or  _no_rule("<defer:$code>",$line);

                $self->{deferrable} = 1;
            }
            elsif ($grammar =~ m/(?=$TOKENPATMK)/gco
                and do { ($code) = extract_codeblock($grammar,'{',undef,'<');
                     $code;
                       } )
            {
                _parse("a token constructor", $aftererror,$line,$code);
                $code =~ s/\A\s*<token:(.*)>\Z/$1/s;

                my $types = eval 'no strict; local $SIG{__WARN__} = sub {0}; my @arr=('.$code.'); @arr' || ();
                if (!$types)
                {
                    _error("Incorrect token specification: \"$@\"", $line);
                    _hint("The <token:...> directive requires a list
                           of one or more strings representing possible
                           types of the specified token. For example:
                           <token:NOUN,VERB>");
                }
                else
                {
                    $item = new Parse::RecDescent::_Runtime::Directive(
                              'no strict;
                               $return = { text => $item[-1] };
                               @{$return->{type}}{'.$code.'} = (1..'.$types.');',
                              $lookahead,$line,"<token:$code>");
                    $prod and $prod->additem($item)
                          or  _no_rule("<token:$code>",$line);
                }
            }
            elsif ($grammar =~ m/$COMMITMK/gco)
            {
                _parse("an commit marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::Directive('$commit = 1',
                                  $lookahead,$line,"<commit>");
                $prod and $prod->additem($item)
                      or  _no_rule("<commit>",$line);
            }
            elsif ($grammar =~ m/$NOCHECKMK/gco) {
                _parse("an hint request", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
        $::RD_CHECK = 0;
        }
            elsif ($grammar =~ m/$HINTMK/gco) {
                _parse("an hint request", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
        $::RD_HINT = $self->{__HINT__} = 1;
        }
            elsif ($grammar =~ m/$WARNMK/gco) {
                _parse("an warning request", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
        $::RD_WARN = $self->{__WARN__} = $1 ? $2+0 : 1;
        }
            elsif ($grammar =~ m/$TRACEBUILDMK/gco) {
                _parse("an grammar build trace request", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
        $::RD_TRACE = $1 ? $2+0 : 1;
        }
            elsif ($grammar =~ m/$TRACEPARSEMK/gco) {
                _parse("an parse trace request", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
        $self->{__TRACE__} = $1 ? $2+0 : 1;
        }
            elsif ($grammar =~ m/$AUTOERRORMK/gco)
            {
                $commitonly = $1;
                _parse("an error marker", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
                $item = new Parse::RecDescent::_Runtime::Error('',$lookahead,$1,$line);
                $prod and $prod->additem($item)
                      or  _no_rule("<error>",$line);
                $aftererror = !$commitonly;
            }
            elsif ($grammar =~ m/(?=$MSGERRORMK)/gco
                and do { $commitonly = $1;
                     ($code) = extract_bracketed($grammar,'<');
                    $code })
            {
                _parse("an error marker", $aftererror,$line,$code);
                $code =~ /\A\s*<error\??:(.*)>\Z/s;
                $item = new Parse::RecDescent::_Runtime::Error($1,$lookahead,$commitonly,$line);
                $prod and $prod->additem($item)
                      or  _no_rule("$code",$line);
                $aftererror = !$commitonly;
            }
            elsif (do { $commitonly = $1;
                     ($code) = extract_bracketed($grammar,'<');
                    $code })
            {
                if ($code =~ /^<[A-Z_]+>$/)
                {
                    _error("Token items are not yet
                    supported: \"$code\"",
                           $line);
                    _hint("Items like $code that consist of angle
                    brackets enclosing a sequence of
                    uppercase characters will eventually
                    be used to specify pre-lexed tokens
                    in a grammar. That functionality is not
                    yet implemented. Or did you misspell
                    \"$code\"?");
                }
                else
                {
                    _error("Untranslatable item encountered: \"$code\"",
                           $line);
                    _hint("Did you misspell \"$code\"
                           or forget to comment it out?");
                }
            }
        }
        elsif ($grammar =~ m/$RULE/gco)
        {
            _parseunneg("a rule declaration", 0,
                    $lookahead,$line, substr($grammar, $-[0], $+[0] - $-[0]) ) or next;
            my $rulename = $1;
            if ($rulename =~ /Replace|Extend|Precompile|Save/ )
            {
                _warn(2,"Rule \"$rulename\" hidden by method
                       Parse::RecDescent::_Runtime::$rulename",$line)
                and
                _hint("The rule named \"$rulename\" cannot be directly
                       called through the Parse::RecDescent::_Runtime object
                       for this grammar (although it may still
                       be used as a subrule of other rules).
                       It can't be directly called because
                       Parse::RecDescent::_Runtime::$rulename is already defined (it
                       is the standard method of all
                       parsers).");
            }
            $rule = new Parse::RecDescent::_Runtime::Rule($rulename,$self,$line,$replace);
            $prod->check_pending($line) if $prod;
            $prod = $rule->addprod( new Parse::RecDescent::_Runtime::Production );
            $aftererror = 0;
        }
        elsif ($grammar =~ m/$UNCOMMITPROD/gco)
        {
            pos($grammar)-=9;
            _parseunneg("a new (uncommitted) production",
                    0, $lookahead, $line, substr($grammar, $-[0], $+[0] - $-[0]) ) or next;

            $prod->check_pending($line) if $prod;
            $prod = new Parse::RecDescent::_Runtime::Production($line,1);
            $rule and $rule->addprod($prod)
                  or  _no_rule("<uncommit>",$line);
            $aftererror = 0;
        }
        elsif ($grammar =~ m/$ERRORPROD/gco)
        {
            pos($grammar)-=6;
            _parseunneg("a new (error) production", $aftererror,
                    $lookahead,$line, substr($grammar, $-[0], $+[0] - $-[0]) ) or next;
            $prod->check_pending($line) if $prod;
            $prod = new Parse::RecDescent::_Runtime::Production($line,0,1);
            $rule and $rule->addprod($prod)
                  or  _no_rule("<error>",$line);
            $aftererror = 0;
        }
        elsif ($grammar =~ m/$PROD/gco)
        {
            _parseunneg("a new production", 0,
                    $lookahead,$line, substr($grammar, $-[0], $+[0] - $-[0]) ) or next;
            $rule
              and (!$prod || $prod->check_pending($line))
              and $prod = $rule->addprod(new Parse::RecDescent::_Runtime::Production($line))
            or  _no_rule("production",$line);
            $aftererror = 0;
        }
        elsif ($grammar =~ m/$LITERAL/gco)
        {
            my $literal = $1;
            ($code = $literal) =~ s/\\\\/\\/g;
            _parse("a literal terminal", $aftererror,$line,$literal);
            $item = new Parse::RecDescent::_Runtime::Literal($code,$lookahead,$line);
            $prod and $prod->additem($item)
                  or  _no_rule("literal terminal",$line,"'$literal'");
        }
        elsif ($grammar =~ m/$INTERPLIT/gco)
        {
            _parse("an interpolated literal terminal", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
            $item = new Parse::RecDescent::_Runtime::InterpLit($1,$lookahead,$line);
            $prod and $prod->additem($item)
                  or  _no_rule("interpolated literal terminal",$line,"'$1'");
        }
        elsif ($grammar =~ m/$TOKEN/gco)
        {
            _parse("a /../ pattern terminal", $aftererror,$line, substr($grammar, $-[0], $+[0] - $-[0]) );
            $item = new Parse::RecDescent::_Runtime::Token($1,'/',$3?$3:'',$lookahead,$line);
            $prod and $prod->additem($item)
                  or  _no_rule("pattern terminal",$line,"/$1/");
        }
        elsif ($grammar =~ m/(?=$MTOKEN)/gco
            and do { ($code, undef, @components)
                    = extract_quotelike($grammar);
                 $code }
              )

        {
            _parse("an m/../ pattern terminal", $aftererror,$line,$code);
            $item = new Parse::RecDescent::_Runtime::Token(@components[3,2,8],
                                 $lookahead,$line);
            $prod and $prod->additem($item)
                  or  _no_rule("pattern terminal",$line,$code);
        }
        elsif ($grammar =~ m/(?=$MATCHRULE)/gco
                and do { ($code) = extract_bracketed($grammar,'<');
                     $code
                       }
               or $grammar =~ m/$SUBRULE/gco
                and $code = $1)
        {
            my $name = $code;
            my $matchrule = 0;
            if (substr($name,0,1) eq '<')
            {
                $name =~ s/$MATCHRULE\s*//;
                $name =~ s/\s*>\Z//;
                $matchrule = 1;
            }

        # EXTRACT TRAILING ARG LIST (IF ANY)

            my ($argcode) = extract_codeblock($grammar, "[]",'') || '';

        # EXTRACT TRAILING REPETITION SPECIFIER (IF ANY)

            if ($grammar =~ m/\G[(]/gc)
            {
                pos($grammar)--;

                if ($grammar =~ m/$OPTIONAL/gco)
                {
                    _parse("an zero-or-one subrule match", $aftererror,$line,"$code$argcode($1)");
                    $item = new Parse::RecDescent::_Runtime::Repetition($name,$1,0,1,
                                       $lookahead,$line,
                                       $self,
                                       $matchrule,
                                       $argcode);
                    $prod and $prod->additem($item)
                          or  _no_rule("repetition",$line,"$code$argcode($1)");

                    !$matchrule and $rule and $rule->addcall($name);
                }
                elsif ($grammar =~ m/$ANY/gco)
                {
                    _parse("a zero-or-more subrule match", $aftererror,$line,"$code$argcode($1)");
                    if ($2)
                    {
                        my $pos = pos $grammar;
                        substr($grammar,$pos,0,
                               "<leftop='$name(s?)': $name $2 $name>(s?) ");

                        pos $grammar = $pos;
                    }
                    else
                    {
                        $item = new Parse::RecDescent::_Runtime::Repetition($name,$1,0,$MAXREP,
                                           $lookahead,$line,
                                           $self,
                                           $matchrule,
                                           $argcode);
                        $prod and $prod->additem($item)
                              or  _no_rule("repetition",$line,"$code$argcode($1)");

                        !$matchrule and $rule and $rule->addcall($name);

                        _check_insatiable($name,$1,$grammar,$line) if $::RD_CHECK;
                    }
                }
                elsif ($grammar =~ m/$MANY/gco)
                {
                    _parse("a one-or-more subrule match", $aftererror,$line,"$code$argcode($1)");
                    if ($2)
                    {
                        # $DB::single=1;
                        my $pos = pos $grammar;
                        substr($grammar,$pos,0,
                               "<leftop='$name(s)': $name $2 $name> ");

                        pos $grammar = $pos;
                    }
                    else
                    {
                        $item = new Parse::RecDescent::_Runtime::Repetition($name,$1,1,$MAXREP,
                                           $lookahead,$line,
                                           $self,
                                           $matchrule,
                                           $argcode);

                        $prod and $prod->additem($item)
                              or  _no_rule("repetition",$line,"$code$argcode($1)");

                        !$matchrule and $rule and $rule->addcall($name);

                        _check_insatiable($name,$1,$grammar,$line) if $::RD_CHECK;
                    }
                }
                elsif ($grammar =~ m/$EXACTLY/gco)
                {
                    _parse("an exactly-$1-times subrule match", $aftererror,$line,"$code$argcode($1)");
                    if ($2)
                    {
                        my $pos = pos $grammar;
                        substr($grammar,$pos,0,
                               "<leftop='$name($1)': $name $2 $name>($1) ");

                        pos $grammar = $pos;
                    }
                    else
                    {
                        $item = new Parse::RecDescent::_Runtime::Repetition($name,$1,$1,$1,
                                           $lookahead,$line,
                                           $self,
                                           $matchrule,
                                           $argcode);
                        $prod and $prod->additem($item)
                              or  _no_rule("repetition",$line,"$code$argcode($1)");

                        !$matchrule and $rule and $rule->addcall($name);
                    }
                }
                elsif ($grammar =~ m/$BETWEEN/gco)
                {
                    _parse("a $1-to-$2 subrule match", $aftererror,$line,"$code$argcode($1..$2)");
                    if ($3)
                    {
                        my $pos = pos $grammar;
                        substr($grammar,$pos,0,
                               "<leftop='$name($1..$2)': $name $3 $name>($1..$2) ");

                        pos $grammar = $pos;
                    }
                    else
                    {
                        $item = new Parse::RecDescent::_Runtime::Repetition($name,"$1..$2",$1,$2,
                                           $lookahead,$line,
                                           $self,
                                           $matchrule,
                                           $argcode);
                        $prod and $prod->additem($item)
                              or  _no_rule("repetition",$line,"$code$argcode($1..$2)");

                        !$matchrule and $rule and $rule->addcall($name);
                    }
                }
                elsif ($grammar =~ m/$ATLEAST/gco)
                {
                    _parse("a $1-or-more subrule match", $aftererror,$line,"$code$argcode($1..)");
                    if ($2)
                    {
                        my $pos = pos $grammar;
                        substr($grammar,$pos,0,
                               "<leftop='$name($1..)': $name $2 $name>($1..) ");

                        pos $grammar = $pos;
                    }
                    else
                    {
                        $item = new Parse::RecDescent::_Runtime::Repetition($name,"$1..",$1,$MAXREP,
                                           $lookahead,$line,
                                           $self,
                                           $matchrule,
                                           $argcode);
                        $prod and $prod->additem($item)
                              or  _no_rule("repetition",$line,"$code$argcode($1..)");

                        !$matchrule and $rule and $rule->addcall($name);
                        _check_insatiable($name,"$1..",$grammar,$line) if $::RD_CHECK;
                    }
                }
                elsif ($grammar =~ m/$ATMOST/gco)
                {
                    _parse("a one-to-$1 subrule match", $aftererror,$line,"$code$argcode(..$1)");
                    if ($2)
                    {
                        my $pos = pos $grammar;
                        substr($grammar,$pos,0,
                               "<leftop='$name(..$1)': $name $2 $name>(..$1) ");

                        pos $grammar = $pos;
                    }
                    else
                    {
                        $item = new Parse::RecDescent::_Runtime::Repetition($name,"..$1",1,$1,
                                           $lookahead,$line,
                                           $self,
                                           $matchrule,
                                           $argcode);
                        $prod and $prod->additem($item)
                              or  _no_rule("repetition",$line,"$code$argcode(..$1)");

                        !$matchrule and $rule and $rule->addcall($name);
                    }
                }
                elsif ($grammar =~ m/$BADREP/gco)
                {
                    my $current_match = substr($grammar, $-[0], $+[0] - $-[0]);
                    _parse("an subrule match with invalid repetition specifier", 0,$line, $current_match);
                    _error("Incorrect specification of a repeated subrule",
                           $line);
                    _hint("Repeated subrules like \"$code$argcode$current_match\" cannot have
                           a maximum repetition of zero, nor can they have
                           negative components in their ranges.");
                }
            }
            else
            {
                _parse("a subrule match", $aftererror,$line,$code);
                my $desc;
                if ($name=~/\A_alternation_\d+_of_production_\d+_of_rule/)
                    { $desc = $self->{"rules"}{$name}->expected }
                $item = new Parse::RecDescent::_Runtime::Subrule($name,
                                       $lookahead,
                                       $line,
                                       $desc,
                                       $matchrule,
                                       $argcode);

                $prod and $prod->additem($item)
                      or  _no_rule("(sub)rule",$line,$name);

                !$matchrule and $rule and $rule->addcall($name);
            }
        }
        elsif ($grammar =~ m/$LONECOLON/gco   )
        {
            _error("Unexpected colon encountered", $line);
            _hint("Did you mean \"|\" (to start a new production)?
                   Or perhaps you forgot that the colon
                   in a rule definition must be
                   on the same line as the rule name?");
        }
        elsif ($grammar =~ m/$ACTION/gco   ) # BAD ACTION, ALREADY FAILED
        {
            _error("Malformed action encountered",
                   $line);
            _hint("Did you forget the closing curly bracket
                   or is there a syntax error in the action?");
        }
        elsif ($grammar =~ m/$OTHER/gco   )
        {
            _error("Untranslatable item encountered: \"$1\"",
                   $line);
            _hint("Did you misspell \"$1\"
                   or forget to comment it out?");
        }

        if ($lookaheadspec =~ tr /././ > 3)
        {
            $lookaheadspec =~ s/\A\s+//;
            $lookahead = $lookahead<0
                    ? 'a negative lookahead ("...!")'
                    : 'a positive lookahead ("...")' ;
            _warn(1,"Found two or more lookahead specifiers in a
                   row.",$line)
            and
            _hint("Multiple positive and/or negative lookaheads
                   are simply multiplied together to produce a
                   single positive or negative lookahead
                   specification. In this case the sequence
                   \"$lookaheadspec\" was reduced to $lookahead.
                   Was this your intention?");
        }
        $lookahead = 0;
        $lookaheadspec = "";

        $grammar =~ m/\G\s+/gc;
    }

    if ($must_pop_lines) {
        pop @lines;
    }

    unless ($ERRORS or $isimplicit or !$::RD_CHECK)
    {
        $self->_check_grammar();
    }

    unless ($ERRORS or $isimplicit or $Parse::RecDescent::_Runtime::compiling)
    {
        my $code = $self->_code();
        if (defined $::RD_TRACE)
        {
            my $mode = ($nextnamespace eq "namespace000002") ? '>' : '>>';
            print STDERR "printing code (", length($code),") to RD_TRACE\n";
            local *TRACE_FILE;
            open TRACE_FILE, $mode, "RD_TRACE"
            and print TRACE_FILE "my \$ERRORS;\n$code"
            and close TRACE_FILE;
        }

        unless ( eval "$code 1" )
        {
            _error("Internal error in generated parser code!");
            $@ =~ s/at grammar/in grammar at/;
            _hint($@);
        }
    }

    if ($ERRORS and !_verbosity("HINT"))
    {
        local $::RD_HINT = defined $::RD_HINT ? $::RD_HINT : 1;
        _hint('Set $::RD_HINT (or -RD_HINT if you\'re using "perl -s")
               for hints on fixing these problems.  Use $::RD_HINT = 0
               to disable this message.');
    }
    if ($ERRORS) { $ERRORS=0; return }
    return $self;
}


sub _addstartcode($$)
{
    my ($self, $code) = @_;
    $code =~ s/\A\s*\{(.*)\}\Z/$1/s;

    $self->{"startcode"} .= "$code;\n";
}

# CHECK FOR GRAMMAR PROBLEMS....

sub _check_insatiable($$$$)
{
    my ($subrule,$repspec,$grammar,$line) = @_;
    pos($grammar)=pos($_[2]);
    return if $grammar =~ m/$OPTIONAL/gco || $grammar =~ m/$ANY/gco;
    my $min = 1;
    if ( $grammar =~ m/$MANY/gco
      || $grammar =~ m/$EXACTLY/gco
      || $grammar =~ m/$ATMOST/gco
      || $grammar =~ m/$BETWEEN/gco && do { $min=$2; 1 }
      || $grammar =~ m/$ATLEAST/gco && do { $min=$2; 1 }
      || $grammar =~ m/$SUBRULE(?!\s*:)/gco
       )
    {
        return unless $1 eq $subrule && $min > 0;
        my $current_match = substr($grammar, $-[0], $+[0] - $-[0]);
        _warn(3,"Subrule sequence \"$subrule($repspec) $current_match\" will
               (almost certainly) fail.",$line)
        and
        _hint("Unless subrule \"$subrule\" performs some cunning
               lookahead, the repetition \"$subrule($repspec)\" will
               insatiably consume as many matches of \"$subrule\" as it
               can, leaving none to match the \"$current_match\" that follows.");
    }
}

sub _check_grammar ($)
{
    my $self = shift;
    my $rules = $self->{"rules"};
    my $rule;
    foreach $rule ( values %$rules )
    {
        next if ! $rule->{"changed"};

    # CHECK FOR UNDEFINED RULES

        my $call;
        foreach $call ( @{$rule->{"calls"}} )
        {
            if (!defined ${$rules}{$call}
              &&!defined &{"Parse::RecDescent::_Runtime::$call"})
            {
                if (!defined $::RD_AUTOSTUB)
                {
                    _warn(3,"Undefined (sub)rule \"$call\"
                          used in a production.")
                    and
                    _hint("Will you be providing this rule
                           later, or did you perhaps
                           misspell \"$call\"? Otherwise
                           it will be treated as an
                           immediate <reject>.");
                    eval "sub $self->{namespace}::$call {undef}";
                }
                else    # EXPERIMENTAL
                {
                    my $rule = qq{'$call'};
                    if ($::RD_AUTOSTUB and $::RD_AUTOSTUB ne "1") {
                        $rule = $::RD_AUTOSTUB;
                    }
                    _warn(1,"Autogenerating rule: $call")
                    and
                    _hint("A call was made to a subrule
                           named \"$call\", but no such
                           rule was specified. However,
                           since \$::RD_AUTOSTUB
                           was defined, a rule stub
                           ($call : $rule) was
                           automatically created.");

                    $self->_generate("$call: $rule",0,1);
                }
            }
        }

    # CHECK FOR LEFT RECURSION

        if ($rule->isleftrec($rules))
        {
            _error("Rule \"$rule->{name}\" is left-recursive.");
            _hint("Redesign the grammar so it's not left-recursive.
                   That will probably mean you need to re-implement
                   repetitions using the '(s)' notation.
                   For example: \"$rule->{name}(s)\".");
            next;
        }

    # CHECK FOR PRODUCTIONS FOLLOWING EMPTY PRODUCTIONS
      {
          my $hasempty;
          my $prod;
          foreach $prod ( @{$rule->{"prods"}} ) {
              if ($hasempty) {
                  _error("Production " . $prod->describe . " for \"$rule->{name}\"
                         will never be reached (preceding empty production will
                         always match first).");
                  _hint("Reorder the grammar so that the empty production
                         is last in the list or productions.");
                  last;
              }
              $hasempty ||= $prod->isempty();
          }
      }
    }
}

# GENERATE ACTUAL PARSER CODE

sub _code($)
{
    my $self = shift;
    my $initial_skip = defined($self->{skip}) ? $self->{skip} : $skip;

    my $code = qq!
package $self->{namespace};
use strict;
use vars qw(\$skip \$AUTOLOAD $self->{localvars} );
\@$self->{namespace}\::ISA = ();
\$skip = '$initial_skip';
$self->{startcode}

{
local \$SIG{__WARN__} = sub {0};
# PRETEND TO BE IN Parse::RecDescent::_Runtime NAMESPACE
*$self->{namespace}::AUTOLOAD   = sub
{
    no strict 'refs';
!
# This generated code uses ${"AUTOLOAD"} rather than $AUTOLOAD in
# order to avoid the circular reference documented here:
#    https://rt.perl.org/rt3/Public/Bug/Display.html?id=110248
# As a result of the investigation of
#    https://rt.cpan.org/Ticket/Display.html?id=53710
. qq!
    \${"AUTOLOAD"} =~ s/^$self->{namespace}/Parse::RecDescent::_Runtime/;
    goto &{\${"AUTOLOAD"}};
}
}

!;
    $code .= "push \@$self->{namespace}\::ISA, 'Parse::RecDescent::_Runtime';";
    $self->{"startcode"} = '';

    my $rule;
    foreach $rule ( values %{$self->{"rules"}} )
    {
        if ($rule->{"changed"})
        {
            $code .= $rule->code($self->{"namespace"},$self);
            $rule->{"changed"} = 0;
        }
    }

    return $code;
}


# EXECUTING A PARSE....

sub AUTOLOAD    # ($parser, $text; $linenum, @args)
{
    croak "Could not find method: $AUTOLOAD\n" unless ref $_[0];
    my $class = ref($_[0]) || $_[0];
    my $text = ref($_[1]) eq 'SCALAR' ? ${$_[1]} : "$_[1]";
    $_[0]->{lastlinenum} = _linecount($text);
    $_[0]->{lastlinenum} += ($_[2]||0) if @_ > 2;
    $_[0]->{offsetlinenum} = $_[0]->{lastlinenum};
    $_[0]->{fulltext} = $text;
    $_[0]->{fulltextlen} = length $text;
    $_[0]->{linecounter_cache} = {};
    $_[0]->{deferred} = [];
    $_[0]->{errors} = [];
    my @args = @_[3..$#_];
    my $args = sub { [ @args ] };

    $AUTOLOAD =~ s/$class/$_[0]->{namespace}/;
    no strict "refs";

    local $::RD_WARN  = $::RD_WARN  || $_[0]->{__WARN__};
    local $::RD_HINT  = $::RD_HINT  || $_[0]->{__HINT__};
    local $::RD_TRACE = $::RD_TRACE || $_[0]->{__TRACE__};

    croak "Unknown starting rule ($AUTOLOAD) called\n"
        unless defined &$AUTOLOAD;
    my $retval = &{$AUTOLOAD}(
        $_[0], # $parser
        $text, # $text
        undef, # $repeating
        undef, # $_noactions
        $args, # \@args
        undef, # $_itempos
    );


    if (defined $retval)
    {
        foreach ( @{$_[0]->{deferred}} ) { &$_; }
    }
    else
    {
        foreach ( @{$_[0]->{errors}} ) { _error(@$_); }
    }

    if (ref $_[1] eq 'SCALAR') { ${$_[1]} = $text }

    $ERRORS = 0;
    return $retval;
}

sub _parserepeat($$$$$$$$$)    # RETURNS A REF TO AN ARRAY OF MATCHES
{
    my ($parser, $text, $prod, $min, $max, $_noactions, $expectation, $argcode, $_itempos) = @_;
    my @tokens = ();

    my $itemposfirst;
    my $reps;
    for ($reps=0; $reps<$max;)
    {
        $expectation->at($text);
        my $_savetext = $text;
        my $prevtextlen = length $text;
        my $_tok;
        if (! defined ($_tok = &$prod($parser,$text,1,$_noactions,$argcode,$_itempos)))
        {
            $text = $_savetext;
            last;
        }

        if (defined($_itempos) and !defined($itemposfirst))
        {
            $itemposfirst = Parse::RecDescent::_Runtime::Production::_duplicate_itempos($_itempos);
        }

        push @tokens, $_tok if defined $_tok;
        last if ++$reps >= $min and $prevtextlen == length $text;
    }

    do { $expectation->failed(); return undef} if $reps<$min;

    if (defined $itemposfirst)
    {
        Parse::RecDescent::_Runtime::Production::_update_itempos($_itempos, $itemposfirst, undef, [qw(from)]);
    }

    $_[1] = $text;
    return [@tokens];
}

sub set_autoflush {
    my $orig_selected = select $_[0];
    $| = 1;
    select $orig_selected;
    return;
}

# ERROR REPORTING....

sub _write_ERROR {
    my ($errorprefix, $errortext) = @_;
    return if $errortext !~ /\S/;
    $errorprefix =~ s/\s+\Z//;
    local $^A = q{};

    formline(<<'END_FORMAT', $errorprefix, $errortext);
@>>>>>>>>>>>>>>>>>>>>: ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END_FORMAT
    formline(<<'END_FORMAT', $errortext);
~~                     ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
END_FORMAT
    print {*STDERR} $^A;
}

# TRACING

my $TRACE_FORMAT = <<'END_FORMAT';
@>|@|||||||||@^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<|
  | ~~       |^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<|
END_FORMAT

my $TRACECONTEXT_FORMAT = <<'END_FORMAT';
@>|@|||||||||@                                      |^<<<<<<<<<<<<<<<<<<<<<<<<<<<
  | ~~       |                                      |^<<<<<<<<<<<<<<<<<<<<<<<<<<<
END_FORMAT

sub _write_TRACE {
    my ($tracelevel, $tracerulename, $tracemsg) = @_;
    return if $tracemsg !~ /\S/;
    $tracemsg =~ s/\s*\Z//;
    local $^A = q{};
    my $bar = '|';
    formline($TRACE_FORMAT, $tracelevel, $tracerulename, $bar, $tracemsg, $tracemsg);
    print {*STDERR} $^A;
}

sub _write_TRACECONTEXT {
    my ($tracelevel, $tracerulename, $tracecontext) = @_;
    return if $tracecontext !~ /\S/;
    $tracecontext =~ s/\s*\Z//;
    local $^A = q{};
    my $bar = '|';
    formline($TRACECONTEXT_FORMAT, $tracelevel, $tracerulename, $bar, $tracecontext, $tracecontext);
    print {*STDERR} $^A;
}

sub _verbosity($)
{
       defined $::RD_TRACE
    or defined $::RD_HINT    and  $::RD_HINT   and $_[0] =~ /ERRORS|WARN|HINT/
    or defined $::RD_WARN    and  $::RD_WARN   and $_[0] =~ /ERRORS|WARN/
    or defined $::RD_ERRORS  and  $::RD_ERRORS and $_[0] =~ /ERRORS/
}

sub _error($;$)
{
    $ERRORS++;
    return 0 if ! _verbosity("ERRORS");
    my $errortext   = $_[0];
    my $errorprefix = "ERROR" .  ($_[1] ? " (line $_[1])" : "");
    $errortext =~ s/\s+/ /g;
    print {*STDERR} "\n" if _verbosity("WARN");
    _write_ERROR($errorprefix, $errortext);
    return 1;
}

sub _warn($$;$)
{
    return 0 unless _verbosity("WARN") && ($::RD_HINT || $_[0] >= ($::RD_WARN||1));
    my $errortext   = $_[1];
    my $errorprefix = "Warning" .  ($_[2] ? " (line $_[2])" : "");
    print {*STDERR} "\n" if _verbosity("HINT");
    $errortext =~ s/\s+/ /g;
    _write_ERROR($errorprefix, $errortext);
    return 1;
}

sub _hint($)
{
    return 0 unless $::RD_HINT;
    my $errortext = $_[0];
    my $errorprefix = "Hint" .  ($_[1] ? " (line $_[1])" : "");
    $errortext =~ s/\s+/ /g;
    _write_ERROR($errorprefix, $errortext);
    return 1;
}

sub _tracemax($)
{
    if (defined $::RD_TRACE
        && $::RD_TRACE =~ /\d+/
        && $::RD_TRACE>1
        && $::RD_TRACE+10<length($_[0]))
    {
        my $count = length($_[0]) - $::RD_TRACE;
        return substr($_[0],0,$::RD_TRACE/2)
            . "...<$count>..."
            . substr($_[0],-$::RD_TRACE/2);
    }
    else
    {
        return substr($_[0],0,500);
    }
}

sub _tracefirst($)
{
    if (defined $::RD_TRACE
        && $::RD_TRACE =~ /\d+/
        && $::RD_TRACE>1
        && $::RD_TRACE+10<length($_[0]))
    {
        my $count = length($_[0]) - $::RD_TRACE;
        return substr($_[0],0,$::RD_TRACE) . "...<+$count>";
    }
    else
    {
        return substr($_[0],0,500);
    }
}

my $lastcontext = '';
my $lastrulename = '';
my $lastlevel = '';

sub _trace($;$$$)
{
    my $tracemsg      = $_[0];
    my $tracecontext  = $_[1]||$lastcontext;
    my $tracerulename = $_[2]||$lastrulename;
    my $tracelevel    = $_[3]||$lastlevel;
    if ($tracerulename) { $lastrulename = $tracerulename }
    if ($tracelevel)    { $lastlevel = $tracelevel }

    $tracecontext =~ s/\n/\\n/g;
    $tracecontext =~ s/\s+/ /g;
    $tracerulename = qq{$tracerulename};
    _write_TRACE($tracelevel, $tracerulename, $tracemsg);
    if ($tracecontext ne $lastcontext)
    {
        if ($tracecontext)
        {
            $lastcontext = _tracefirst($tracecontext);
            $tracecontext = qq{"$tracecontext"};
        }
        else
        {
            $tracecontext = qq{<NO TEXT LEFT>};
        }
        _write_TRACECONTEXT($tracelevel, $tracerulename, $tracecontext);
    }
}

sub _matchtracemessage
{
    my ($self, $reject) = @_;

    my $prefix = '';
    my $postfix = '';
    my $matched = not $reject;
    my @t = ("Matched", "Didn't match");
    if (exists $self->{lookahead} and $self->{lookahead})
    {
        $postfix = $reject ? "(reject)" : "(keep)";
        $prefix = "...";
        if ($self->{lookahead} < 0)
        {
            $prefix .= '!';
            $matched = not $matched;
        }
    }
    $prefix . ($matched ? $t[0] : $t[1]) . $postfix;
}

sub _parseunneg($$$$$)
{
    _parse($_[0],$_[1],$_[3],$_[4]);
    if ($_[2]<0)
    {
        _error("Can't negate \"$_[4]\".",$_[3]);
        _hint("You can't negate $_[0]. Remove the \"...!\" before
               \"$_[4]\".");
        return 0;
    }
    return 1;
}

sub _parse($$$$)
{
    my $what = $_[3];
       $what =~ s/^\s+//;
    if ($_[1])
    {
        _warn(3,"Found $_[0] ($what) after an unconditional <error>",$_[2])
        and
        _hint("An unconditional <error> always causes the
               production containing it to immediately fail.
               \u$_[0] that follows an <error>
               will never be reached.  Did you mean to use
               <error?> instead?");
    }

    return if ! _verbosity("TRACE");
    my $errortext = "Treating \"$what\" as $_[0]";
    my $errorprefix = "Parse::RecDescent::_Runtime";
    $errortext =~ s/\s+/ /g;
    _write_ERROR($errorprefix, $errortext);
}

sub _linecount($) {
    scalar substr($_[0], pos $_[0]||0) =~ tr/\n//
}


package main;

use vars qw ( $RD_ERRORS $RD_WARN $RD_HINT $RD_TRACE $RD_CHECK );
$::RD_CHECK = 1;
$::RD_ERRORS = 1;
$::RD_WARN = 3;

1;

}

package Treex::Core::ScenarioParser;

{ my $ERRORS;


package Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser;
use strict;
use vars qw($skip $AUTOLOAD  );
@Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::ISA = ();
$skip = '\s*';

use File::Slurp;
use File::Basename;
use Treex::Core::Log;
## no critic (Miscellanea::ProhibitUnrestrictedNoCritic)
## no critic Generated code follows
no warnings;
;


{
local $SIG{__WARN__} = sub {0};
# PRETEND TO BE IN Parse::RecDescent::_Runtime NAMESPACE
*Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::AUTOLOAD   = sub
{
    no strict 'refs';

    ${"AUTOLOAD"} =~ s/^Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser/Parse::RecDescent::_Runtime/;
    goto &{${"AUTOLOAD"}};
}
}

push @Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::ISA, 'Parse::RecDescent::_Runtime';
# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PNOTQUOTED
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PNOTQUOTED"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PNOTQUOTED]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/\\S+/, or EMPTY});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/\\S+/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PNOTQUOTED});
        %item = (__RULE__ => q{PNOTQUOTED});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/\\S+/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\S+)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/\\S+/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [EMPTY]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PNOTQUOTED});
        %item = (__RULE__ => q{PNOTQUOTED});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [EMPTY]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PNOTQUOTED},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::EMPTY($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [EMPTY]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PNOTQUOTED},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [EMPTY]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{EMPTY}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = ''};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [EMPTY]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PNOTQUOTED},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PNOTQUOTED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PNOTQUOTED},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PNOTQUOTED},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PARAMS
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PARAMS"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PARAMS]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{PARAM});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [PARAM PARAMS]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PARAMS});
        %item = (__RULE__ => q{PARAMS});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PARAM]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PARAMS},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PARAM($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PARAM]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PARAMS},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PARAM]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAM}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PARAMS]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PARAMS},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PARAMS})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PARAMS($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PARAMS]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PARAMS},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PARAMS]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAMS}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [$item{PARAM}, @{$item{PARAMS}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [PARAM PARAMS]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [PARAM]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PARAMS});
        %item = (__RULE__ => q{PARAMS});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PARAM]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PARAMS},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PARAM($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PARAM]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PARAMS},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PARAM]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAM}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [$item{PARAM}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [PARAM]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PARAMS},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PARAMS},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PARAMS},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PARAMS},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PARAM
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PARAM"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PARAM]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{PNAME});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        local $skip = defined($skip) ? $skip : $Parse::RecDescent::_Runtime::skip;
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [PNAME '=' <skip: qr//> PVALUE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PARAM});
        %item = (__RULE__ => q{PARAM});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PARAM},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PNAME]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PARAM},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PNAME]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: ['=']},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{'='})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A\=/)
        {
            $text = $lastsep . $text if defined $lastsep;
            
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(qq{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
        push @item, $item{__STRING1__}=$current_match;
        

        

        Parse::RecDescent::_Runtime::_trace(q{Trying directive: [<skip: qr//>]},
                    Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE; 
        $_tok = do { my $oldskip = $skip; $skip= qr//; $oldskip };
        if (defined($_tok))
        {
            Parse::RecDescent::_Runtime::_trace(q{>>Matched directive<< (return value: [}
                        . $_tok . q{])},
                        Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        else
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match directive>>},
                        Parse::RecDescent::_Runtime::_tracefirst($text))
                            if defined $::RD_TRACE;
        }
        
        last unless defined $_tok;
        push @item, $item{__DIRECTIVE1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PVALUE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PARAM},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PVALUE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PVALUE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PVALUE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PARAM},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PVALUE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PVALUE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PNAME}.'='.$item{PVALUE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [PNAME '=' <skip: qr//> PVALUE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PARAM},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PARAM},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PARAM},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PARAM},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::LINE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"LINE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [LINE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{BLOCK, or COMMENT});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [BLOCK COMMENT]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{LINE});
        %item = (__RULE__ => q{LINE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [BLOCK]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BLOCK($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [BLOCK]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [BLOCK]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BLOCK}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [COMMENT]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{COMMENT})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::COMMENT($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [COMMENT]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [COMMENT]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{COMMENT}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{BLOCK}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [BLOCK COMMENT]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [BLOCK]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{LINE});
        %item = (__RULE__ => q{LINE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [BLOCK]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BLOCK($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [BLOCK]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [BLOCK]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BLOCK}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{BLOCK}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [BLOCK]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [COMMENT]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{LINE});
        %item = (__RULE__ => q{LINE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [COMMENT]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{LINE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::COMMENT($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [COMMENT]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{LINE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [COMMENT]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{COMMENT}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = []};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [COMMENT]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{LINE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{LINE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{LINE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{LINE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::EMPTY
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"EMPTY"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [EMPTY]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{//});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [//]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{EMPTY});
        %item = (__RULE__ => q{EMPTY});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [//]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [//]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{EMPTY},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{EMPTY},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{EMPTY},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{EMPTY},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BNAME
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"BNAME"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [BNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/[A-Z]\\w*::/, or /[A-Z]\\w*/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/[A-Z]\\w*::/ BNAME]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{BNAME});
        %item = (__RULE__ => q{BNAME});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/[A-Z]\\w*::/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[A-Z]\w*::)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [BNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{BNAME})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [BNAME]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BNAME},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [BNAME]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1].$item[2]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/[A-Z]\\w*::/ BNAME]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/[A-Z]\\w*/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{BNAME});
        %item = (__RULE__ => q{BNAME});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/[A-Z]\\w*/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[A-Z]\w*)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/[A-Z]\\w*/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{BNAME},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{BNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{BNAME},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{BNAME},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SLASHEDDQUOTE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SLASHEDDQUOTE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [SLASHEDDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                  q{SLASHEDDQUOTE},
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/\\\\"/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/\\\\"/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{SLASHEDDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SLASHEDDQUOTE});
        %item = (__RULE__ => q{SLASHEDDQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/\\\\"/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SLASHEDDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\\")/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SLASHEDDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = '"'};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/\\\\"/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SLASHEDDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{SLASHEDDQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{SLASHEDDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SLASHEDDQUOTE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{SLASHEDDQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::NOTDQUOTE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"NOTDQUOTE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [NOTDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                  q{NOTDQUOTE},
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/[^"]*[^"\\\\]/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/[^"]*[^"\\\\]/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{NOTDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{NOTDQUOTE});
        %item = (__RULE__ => q{NOTDQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/[^"]*[^"\\\\]/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{NOTDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^"]*[^"\\])/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/[^"]*[^"\\\\]/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{NOTDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{NOTDQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{NOTDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{NOTDQUOTE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{NOTDQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::NOTSQUOTE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"NOTSQUOTE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [NOTSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/[^']*[^'\\\\]/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/[^']*[^'\\\\]/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{NOTSQUOTE});
        %item = (__RULE__ => q{NOTSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/[^']*[^'\\\\]/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^']*[^'\\])/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/[^']*[^'\\\\]/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{NOTSQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{NOTSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{NOTSQUOTE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{NOTSQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::INCLUDE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"INCLUDE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [INCLUDE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/\\/\\S+\\.scen/, or /[^\\/#]\\S+\\.scen/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/\\/\\S+\\.scen/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{INCLUDE});
        %item = (__RULE__ => q{INCLUDE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/\\/\\S+\\.scen/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\/\S+\.scen)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/\\/\\S+\\.scen/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/[^\\/#]\\S+\\.scen/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{INCLUDE});
        %item = (__RULE__ => q{INCLUDE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/[^\\/#]\\S+\\.scen/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^\/#]\S+\.scen)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {   my $from_file = $arg[0];
                                                    if (length $from_file) {
                                                        $return = dirname($from_file) . "/$item[1]";
                                                    } else {
                                                        $return = "./$item[1]";
                                                    }
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/[^\\/#]\\S+\\.scen/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{INCLUDE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{INCLUDE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{INCLUDE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{INCLUDE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::EOF
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"EOF"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [EOF]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/^\\Z/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/^\\Z/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{EOF});
        %item = (__RULE__ => q{EOF});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/^\\Z/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:^\Z)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/^\\Z/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{EOF},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{EOF},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{EOF},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{EOF},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PTICKED
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PTICKED"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PTICKED]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/[^`]+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/[^`]+/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PTICKED});
        %item = (__RULE__ => q{PTICKED});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/[^`]+/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:[^`]+)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/[^`]+/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PTICKED},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PTICKED},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PTICKED},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PTICKED},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SPACE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SPACE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [SPACE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/\\s+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/\\s+/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SPACE});
        %item = (__RULE__ => q{SPACE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/\\s+/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\s+)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/\\s+/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{SPACE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{SPACE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SPACE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{SPACE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::TBNAME
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"TBNAME"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [TBNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/::/, or BNAME});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/::/ BNAME]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{TBNAME});
        %item = (__RULE__ => q{TBNAME});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/::/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:::)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [BNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{TBNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{BNAME})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [BNAME]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{TBNAME},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [BNAME]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{BNAME}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/::/ BNAME]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [BNAME]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{TBNAME});
        %item = (__RULE__ => q{TBNAME});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [BNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{TBNAME},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [BNAME]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{TBNAME},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [BNAME]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = "Treex::Block::$item{BNAME}"};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [BNAME]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{TBNAME},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{TBNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{TBNAME},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{TBNAME},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BLOCK
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"BLOCK"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [BLOCK]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{INCLUDE, or SCENMODULE, or TBNAME});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [INCLUDE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [INCLUDE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::INCLUDE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [INCLUDE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [INCLUDE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{INCLUDE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {
                                                    my $included = read_file( $item{INCLUDE}, binmode => ':utf8' );
                                                    my $result = $thisparser->startrule( $included, 1, $item{INCLUDE} );
                                                    if (defined $result and ref $result eq 'ARRAY') {
                                                        $return = [@$result];
                                                    } else {
                                                        $return = undef;
                                                    }
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [INCLUDE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [SCENMODULE PARAMS]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [SCENMODULE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SCENMODULE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [SCENMODULE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [SCENMODULE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SCENMODULE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PARAMS]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PARAMS})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PARAMS($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PARAMS]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PARAMS]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAMS}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {
                                                    my $modulename = $item{SCENMODULE};
                                                    eval "use $modulename; 1;" or die "Can't use $modulename !\n$@\n";
                                                    my %params = map {my ($name,$value) = split /=/, $_, 2; ($name, $value)} @{$item{PARAMS}};
                                                    my $scenmod = $modulename->new(\%params);
                                                    my $string = $scenmod->get_scenario_string();
                                                    my $result = $thisparser->startrule( $string, 0, '' );
                                                    if (defined $result and ref $result eq 'ARRAY') {
                                                        $return = [@$result];
                                                    } else {
                                                        log_fatal "Syntax error in '$modulename' scenario:\n<BEGIN SCENARIO>\n$string\n<END SCENARIO>";
                                                    }
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [SCENMODULE PARAMS]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [SCENMODULE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [SCENMODULE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SCENMODULE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [SCENMODULE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [SCENMODULE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SCENMODULE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {
                                                    my $modulename = $item{SCENMODULE};
                                                    eval "use $modulename; 1;" or die "Can't use $modulename !\n$@\n";
                                                    my $scenmod = $modulename->new();
                                                    my $string = $scenmod->get_scenario_string();
                                                    my $result = $thisparser->startrule( $string, 0, '' );
                                                    if (defined $result and ref $result eq 'ARRAY') {
                                                        $return = [@$result];
                                                    } else {
                                                        log_fatal "Syntax error in '$modulename' scenario:\n<BEGIN SCENARIO>\n$string\n<END SCENARIO>";
                                                    }
                                                };
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [SCENMODULE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [TBNAME PARAMS]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[3];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [TBNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::TBNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [TBNAME]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [TBNAME]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{TBNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PARAMS]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PARAMS})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PARAMS($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PARAMS]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PARAMS]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PARAMS}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
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
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [TBNAME PARAMS]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [TBNAME]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[4];
        $text = $_[1];
        my $_savetext;
        @item = (q{BLOCK});
        %item = (__RULE__ => q{BLOCK});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [TBNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{BLOCK},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::TBNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [TBNAME]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{BLOCK},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [TBNAME]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{TBNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
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
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [TBNAME]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{BLOCK},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{BLOCK},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{BLOCK},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{BLOCK},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::COMMENT
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"COMMENT"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [COMMENT]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/#[^\\n]*/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/#[^\\n]*/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{COMMENT});
        %item = (__RULE__ => q{COMMENT});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/#[^\\n]*/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:#[^\n]*)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = ''};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/#[^\\n]*/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{COMMENT},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{COMMENT},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{COMMENT},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{COMMENT},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::startrule
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"startrule"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [startrule]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{SCEN});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [SCEN EOF]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{startrule});
        %item = (__RULE__ => q{startrule});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [SCEN]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{startrule},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SCEN($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [SCEN]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{startrule},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [SCEN]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SCEN}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [EOF]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{startrule},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{EOF})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::EOF($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [EOF]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{startrule},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [EOF]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{EOF}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{SCEN}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [SCEN EOF]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{startrule},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{startrule},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{startrule},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{startrule},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SCEN
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SCEN"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [SCEN]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{LINE});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [LINE SCEN]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SCEN});
        %item = (__RULE__ => q{SCEN});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [LINE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{SCEN},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::LINE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [LINE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{SCEN},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [LINE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{LINE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [SCEN]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{SCEN},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{SCEN})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SCEN($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [SCEN]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{SCEN},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [SCEN]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SCEN}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{LINE}},@{$item{SCEN}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [LINE SCEN]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [LINE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{SCEN});
        %item = (__RULE__ => q{SCEN});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [LINE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{SCEN},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::LINE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [LINE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{SCEN},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [LINE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{LINE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = [@{$item{LINE}}]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [LINE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{SCEN},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{SCEN},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SCEN},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{SCEN},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SCENMODULE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SCENMODULE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [SCENMODULE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                  q{SCENMODULE},
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/Scen::/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/Scen::/ BNAME]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{SCENMODULE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SCENMODULE});
        %item = (__RULE__ => q{SCENMODULE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/Scen::/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCENMODULE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:Scen::)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [BNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{SCENMODULE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{BNAME})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::BNAME($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [BNAME]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{SCENMODULE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [BNAME]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCENMODULE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{BNAME}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCENMODULE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do { $return = "Treex::Scen::$item{BNAME}"};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/Scen::/ BNAME]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SCENMODULE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{SCENMODULE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{SCENMODULE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SCENMODULE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{SCENMODULE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PVALUE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PVALUE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PVALUE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/'/, or /"/, or /`/, or PNOTQUOTED});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/'/ PSQUOTE /'/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/'/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:')/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PSQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PSQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PSQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/'/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{/'/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:')/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN2__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PSQUOTE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/'/ PSQUOTE /'/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/"/ PDQUOTE /"/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/"/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:")/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PDQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PDQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PDQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PDQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PDQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/"/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{/"/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:")/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN2__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PDQUOTE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/"/ PDQUOTE /"/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/`/ PTICKED /`/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[2];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/`/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:`)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PTICKED]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PTICKED})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PTICKED($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PTICKED]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PTICKED]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PTICKED}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/`/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{/`/})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:`)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN2__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1].$item[2].$item[3]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/`/ PTICKED /`/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [PNOTQUOTED]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[3];
        $text = $_[1];
        my $_savetext;
        @item = (q{PVALUE});
        %item = (__RULE__ => q{PVALUE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PNOTQUOTED]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PVALUE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PNOTQUOTED($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PNOTQUOTED]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PVALUE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PNOTQUOTED]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PNOTQUOTED}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{PNOTQUOTED}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [PNOTQUOTED]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PVALUE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PVALUE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PVALUE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PVALUE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PSQUOTE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PSQUOTE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{NOTSQUOTE});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [NOTSQUOTE SLASHEDSQUOTE PSQUOTE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PSQUOTE});
        %item = (__RULE__ => q{PSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [NOTSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::NOTSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [NOTSQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [NOTSQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{NOTSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [SLASHEDSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{SLASHEDSQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SLASHEDSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [SLASHEDSQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [SLASHEDSQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SLASHEDSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PSQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PSQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PSQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{NOTSQUOTE}.$item{SLASHEDSQUOTE}.$item{PSQUOTE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [NOTSQUOTE SLASHEDSQUOTE PSQUOTE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [NOTSQUOTE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PSQUOTE});
        %item = (__RULE__ => q{PSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [NOTSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PSQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::NOTSQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [NOTSQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PSQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [NOTSQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{NOTSQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [NOTSQUOTE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PSQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PSQUOTE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PSQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SLASHEDSQUOTE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"SLASHEDSQUOTE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [SLASHEDSQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/\\\\'/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/\\\\'/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{SLASHEDSQUOTE});
        %item = (__RULE__ => q{SLASHEDSQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/\\\\'/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\\')/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = "'"};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/\\\\'/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{SLASHEDSQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{SLASHEDSQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{SLASHEDSQUOTE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{SLASHEDSQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PNAME
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PNAME"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PNAME]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{/\\w+/});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [/\\w+/]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PNAME});
        %item = (__RULE__ => q{PNAME});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying terminal: [/\\w+/]}, Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        undef $lastsep;
        $expectation->is(q{})->at($text);
        

        unless ($text =~ s/\A($skip)/$lastsep=$1 and ""/e and   $text =~ m/\A(?:\w+)/)
        {
            $text = $lastsep . $text if defined $lastsep;
            $expectation->failed();
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match terminal>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;

            last;
        }
        $current_match = substr($text, $-[0], $+[0] - $-[0]);
        substr($text,0,length($current_match),q{});
        Parse::RecDescent::_Runtime::_trace(q{>>Matched terminal<< (return value: [}
                        . $current_match . q{])},
                          Parse::RecDescent::_Runtime::_tracefirst($text))
                    if defined $::RD_TRACE;
        push @item, $item{__PATTERN1__}=$current_match;
        

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item[1]};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [/\\w+/]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PNAME},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PNAME},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PNAME},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PNAME},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}

# ARGS ARE: ($parser, $text; $repeating, $_noactions, \@args, $_itempos)
sub Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PDQUOTE
{
    my $thisparser = $_[0];
    use vars q{$tracelevel};
    local $tracelevel = ($tracelevel||0)+1;
    $ERRORS = 0;
    my $thisrule = $thisparser->{"rules"}{"PDQUOTE"};

    Parse::RecDescent::_Runtime::_trace(q{Trying rule: [PDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($_[1]),
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
    my $repeating =  $_[2];
    my $_noactions = $_[3];
    my @arg =    defined $_[4] ? @{ &{$_[4]} } : ();
    my $_itempos = $_[5];
    my %arg =    ($#arg & 01) ? @arg : (@arg, undef);
    my $text;
    my $lastsep;
    my $current_match;
    my $expectation = new Parse::RecDescent::_Runtime::Expectation(q{NOTDQUOTE});
    $expectation->at($_[1]);
    
    my $thisline;
    tie $thisline, q{Parse::RecDescent::_Runtime::LineCounter}, \$text, $thisparser;

    

    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [NOTDQUOTE SLASHEDDQUOTE PDQUOTE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[0];
        $text = $_[1];
        my $_savetext;
        @item = (q{PDQUOTE});
        %item = (__RULE__ => q{PDQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [NOTDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PDQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::NOTDQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [NOTDQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PDQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [NOTDQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{NOTDQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [SLASHEDDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PDQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{SLASHEDDQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::SLASHEDDQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [SLASHEDDQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PDQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [SLASHEDDQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{SLASHEDDQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [PDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PDQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{PDQUOTE})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::PDQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [PDQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PDQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [PDQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{PDQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{Trying action},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        

        $_tok = ($_noactions) ? 0 : do {$return = $item{NOTDQUOTE}.$item{SLASHEDDQUOTE}.$item{PDQUOTE}};
        unless (defined $_tok)
        {
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match action>> (return value: [undef])})
                    if defined $::RD_TRACE;
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched action<< (return value: [}
                      . $_tok . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text))
                        if defined $::RD_TRACE;
        push @item, $_tok;
        $item{__ACTION1__}=$_tok;
        

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [NOTDQUOTE SLASHEDDQUOTE PDQUOTE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    while (!$_matched && !$commit)
    {
        
        Parse::RecDescent::_Runtime::_trace(q{Trying production: [NOTDQUOTE]},
                      Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        my $thisprod = $thisrule->{"prods"}[1];
        $text = $_[1];
        my $_savetext;
        @item = (q{PDQUOTE});
        %item = (__RULE__ => q{PDQUOTE});
        my $repcount = 0;


        Parse::RecDescent::_Runtime::_trace(q{Trying subrule: [NOTDQUOTE]},
                  Parse::RecDescent::_Runtime::_tracefirst($text),
                  q{PDQUOTE},
                  $tracelevel)
                    if defined $::RD_TRACE;
        if (1) { no strict qw{refs};
        $expectation->is(q{})->at($text);
        unless (defined ($_tok = Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser::NOTDQUOTE($thisparser,$text,$repeating,$_noactions,sub { \@arg },undef)))
        {
            
            Parse::RecDescent::_Runtime::_trace(q{<<Didn't match subrule: [NOTDQUOTE]>>},
                          Parse::RecDescent::_Runtime::_tracefirst($text),
                          q{PDQUOTE},
                          $tracelevel)
                            if defined $::RD_TRACE;
            $expectation->failed();
            last;
        }
        Parse::RecDescent::_Runtime::_trace(q{>>Matched subrule: [NOTDQUOTE]<< (return value: [}
                    . $_tok . q{]},

                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $item{q{NOTDQUOTE}} = $_tok;
        push @item, $_tok;
        
        }

        Parse::RecDescent::_Runtime::_trace(q{>>Matched production: [NOTDQUOTE]<<},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;



        $_matched = 1;
        last;
    }


    unless ( $_matched || defined($score) )
    {
        

        $_[1] = $text;  # NOT SURE THIS IS NEEDED
        Parse::RecDescent::_Runtime::_trace(q{<<Didn't match rule>>},
                     Parse::RecDescent::_Runtime::_tracefirst($_[1]),
                     q{PDQUOTE},
                     $tracelevel)
                    if defined $::RD_TRACE;
        return undef;
    }
    if (!defined($return) && defined($score))
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Accepted scored production<<}, "",
                      q{PDQUOTE},
                      $tracelevel)
                        if defined $::RD_TRACE;
        $return = $score_return;
    }
    splice @{$thisparser->{errors}}, $err_at;
    $return = $item[$#item] unless defined $return;
    if (defined $::RD_TRACE)
    {
        Parse::RecDescent::_Runtime::_trace(q{>>Matched rule<< (return value: [} .
                      $return . q{])}, "",
                      q{PDQUOTE},
                      $tracelevel);
        Parse::RecDescent::_Runtime::_trace(q{(consumed: [} .
                      Parse::RecDescent::_Runtime::_tracemax(substr($_[1],0,-length($text))) . q{])},
                      Parse::RecDescent::_Runtime::_tracefirst($text),
                      , q{PDQUOTE},
                      $tracelevel)
    }
    $_[1] = $text;
    return $return;
}
}
package Treex::Core::ScenarioParser; sub new { my $self = bless( {
                 'rules' => {
                              'PNOTQUOTED' => bless( {
                                                       'vars' => '',
                                                       'name' => 'PNOTQUOTED',
                                                       'calls' => [
                                                                    'EMPTY'
                                                                  ],
                                                       'changed' => 0,
                                                       'impcount' => 0,
                                                       'opcount' => 0,
                                                       'line' => 90,
                                                       'prods' => [
                                                                    bless( {
                                                                             'uncommit' => undef,
                                                                             'number' => 0,
                                                                             'actcount' => 1,
                                                                             'patcount' => 1,
                                                                             'strcount' => 0,
                                                                             'items' => [
                                                                                          bless( {
                                                                                                   'pattern' => '\\S+',
                                                                                                   'lookahead' => 0,
                                                                                                   'hashname' => '__PATTERN1__',
                                                                                                   'line' => 90,
                                                                                                   'ldelim' => '/',
                                                                                                   'rdelim' => '/',
                                                                                                   'mod' => '',
                                                                                                   'description' => '/\\\\S+/'
                                                                                                 }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                          bless( {
                                                                                                   'code' => '{$return = $item[1]}',
                                                                                                   'lookahead' => 0,
                                                                                                   'line' => 90,
                                                                                                   'hashname' => '__ACTION1__'
                                                                                                 }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                        ],
                                                                             'line' => undef,
                                                                             'dircount' => 0,
                                                                             'error' => undef
                                                                           }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                    bless( {
                                                                             'actcount' => 1,
                                                                             'patcount' => 0,
                                                                             'uncommit' => undef,
                                                                             'number' => 1,
                                                                             'items' => [
                                                                                          bless( {
                                                                                                   'matchrule' => 0,
                                                                                                   'line' => 91,
                                                                                                   'lookahead' => 0,
                                                                                                   'subrule' => 'EMPTY',
                                                                                                   'implicit' => undef,
                                                                                                   'argcode' => undef
                                                                                                 }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                          bless( {
                                                                                                   'code' => '{$return = \'\'}',
                                                                                                   'hashname' => '__ACTION1__',
                                                                                                   'line' => 91,
                                                                                                   'lookahead' => 0
                                                                                                 }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                        ],
                                                                             'line' => undef,
                                                                             'error' => undef,
                                                                             'dircount' => 0,
                                                                             'strcount' => 0
                                                                           }, 'Parse::RecDescent::_Runtime::Production' )
                                                                  ]
                                                     }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'PARAMS' => bless( {
                                                   'name' => 'PARAMS',
                                                   'calls' => [
                                                                'PARAM',
                                                                'PARAMS'
                                                              ],
                                                   'changed' => 0,
                                                   'impcount' => 0,
                                                   'vars' => '',
                                                   'opcount' => 0,
                                                   'line' => 73,
                                                   'prods' => [
                                                                bless( {
                                                                         'strcount' => 0,
                                                                         'line' => undef,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'argcode' => undef,
                                                                                               'implicit' => undef,
                                                                                               'line' => 73,
                                                                                               'lookahead' => 0,
                                                                                               'subrule' => 'PARAM',
                                                                                               'matchrule' => 0
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'lookahead' => 0,
                                                                                               'subrule' => 'PARAMS',
                                                                                               'line' => 73,
                                                                                               'matchrule' => 0,
                                                                                               'argcode' => undef,
                                                                                               'implicit' => undef
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'line' => 73,
                                                                                               'lookahead' => 0,
                                                                                               'code' => '{$return = [$item{PARAM}, @{$item{PARAMS}}]}'
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'error' => undef,
                                                                         'dircount' => 0,
                                                                         'uncommit' => undef,
                                                                         'number' => 0,
                                                                         'actcount' => 1,
                                                                         'patcount' => 0
                                                                       }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                bless( {
                                                                         'actcount' => 1,
                                                                         'patcount' => 0,
                                                                         'uncommit' => undef,
                                                                         'number' => 1,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'matchrule' => 0,
                                                                                               'subrule' => 'PARAM',
                                                                                               'lookahead' => 0,
                                                                                               'line' => 74,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'lookahead' => 0,
                                                                                               'line' => 74,
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'code' => '{$return = [$item{PARAM}]}'
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'line' => undef,
                                                                         'dircount' => 0,
                                                                         'error' => undef,
                                                                         'strcount' => 0
                                                                       }, 'Parse::RecDescent::_Runtime::Production' )
                                                              ]
                                                 }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'PARAM' => bless( {
                                                  'vars' => '',
                                                  'name' => 'PARAM',
                                                  'calls' => [
                                                               'PNAME',
                                                               'PVALUE'
                                                             ],
                                                  'changed' => 0,
                                                  'impcount' => 0,
                                                  'opcount' => 0,
                                                  'line' => 75,
                                                  'prods' => [
                                                               bless( {
                                                                        'actcount' => 1,
                                                                        'patcount' => 0,
                                                                        'number' => 0,
                                                                        'uncommit' => undef,
                                                                        'error' => undef,
                                                                        'dircount' => 1,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'matchrule' => 0,
                                                                                              'lookahead' => 0,
                                                                                              'subrule' => 'PNAME',
                                                                                              'line' => 75,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'description' => '\'=\'',
                                                                                              'pattern' => '=',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 75,
                                                                                              'hashname' => '__STRING1__'
                                                                                            }, 'Parse::RecDescent::_Runtime::Literal' ),
                                                                                     bless( {
                                                                                              'name' => '<skip: qr//>',
                                                                                              'code' => 'my $oldskip = $skip; $skip= qr//; $oldskip',
                                                                                              'hashname' => '__DIRECTIVE1__',
                                                                                              'line' => 75,
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Directive' ),
                                                                                     bless( {
                                                                                              'argcode' => undef,
                                                                                              'implicit' => undef,
                                                                                              'lookahead' => 0,
                                                                                              'subrule' => 'PVALUE',
                                                                                              'line' => 75,
                                                                                              'matchrule' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'code' => '{$return = $item{PNAME}.\'=\'.$item{PVALUE}}',
                                                                                              'line' => 75,
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'line' => undef,
                                                                        'strcount' => 1
                                                                      }, 'Parse::RecDescent::_Runtime::Production' )
                                                             ]
                                                }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'LINE' => bless( {
                                                 'vars' => '',
                                                 'name' => 'LINE',
                                                 'impcount' => 0,
                                                 'calls' => [
                                                              'BLOCK',
                                                              'COMMENT'
                                                            ],
                                                 'changed' => 0,
                                                 'line' => 12,
                                                 'opcount' => 0,
                                                 'prods' => [
                                                              bless( {
                                                                       'number' => 0,
                                                                       'uncommit' => undef,
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'strcount' => 0,
                                                                       'error' => undef,
                                                                       'dircount' => 0,
                                                                       'line' => undef,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'matchrule' => 0,
                                                                                             'subrule' => 'BLOCK',
                                                                                             'lookahead' => 0,
                                                                                             'line' => 12
                                                                                           }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                    bless( {
                                                                                             'matchrule' => 0,
                                                                                             'line' => 12,
                                                                                             'lookahead' => 0,
                                                                                             'subrule' => 'COMMENT',
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef
                                                                                           }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                    bless( {
                                                                                             'code' => '{$return = [@{$item{BLOCK}}]}',
                                                                                             'lookahead' => 0,
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'line' => 12
                                                                                           }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                  ]
                                                                     }, 'Parse::RecDescent::_Runtime::Production' ),
                                                              bless( {
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'uncommit' => undef,
                                                                       'number' => 1,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'matchrule' => 0,
                                                                                             'subrule' => 'BLOCK',
                                                                                             'lookahead' => 0,
                                                                                             'line' => 13
                                                                                           }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                    bless( {
                                                                                             'code' => '{$return = [@{$item{BLOCK}}]}',
                                                                                             'line' => 13,
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'lookahead' => 0
                                                                                           }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                  ],
                                                                       'line' => undef,
                                                                       'dircount' => 0,
                                                                       'error' => undef,
                                                                       'strcount' => 0
                                                                     }, 'Parse::RecDescent::_Runtime::Production' ),
                                                              bless( {
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'number' => 2,
                                                                       'uncommit' => undef,
                                                                       'dircount' => 0,
                                                                       'error' => undef,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'matchrule' => 0,
                                                                                             'lookahead' => 0,
                                                                                             'subrule' => 'COMMENT',
                                                                                             'line' => 14
                                                                                           }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                    bless( {
                                                                                             'code' => '{$return = []}',
                                                                                             'lookahead' => 0,
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'line' => 14
                                                                                           }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                  ],
                                                                       'line' => undef,
                                                                       'strcount' => 0
                                                                     }, 'Parse::RecDescent::_Runtime::Production' )
                                                            ]
                                               }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'EMPTY' => bless( {
                                                  'line' => 95,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'line' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'mod' => '',
                                                                                              'rdelim' => '/',
                                                                                              'description' => '//',
                                                                                              'line' => 95,
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'lookahead' => 0,
                                                                                              'pattern' => '',
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::_Runtime::Token' )
                                                                                   ],
                                                                        'error' => undef,
                                                                        'dircount' => 0,
                                                                        'strcount' => 0,
                                                                        'actcount' => 0,
                                                                        'patcount' => 1,
                                                                        'uncommit' => undef,
                                                                        'number' => 0
                                                                      }, 'Parse::RecDescent::_Runtime::Production' )
                                                             ],
                                                  'name' => 'EMPTY',
                                                  'impcount' => 0,
                                                  'changed' => 0,
                                                  'calls' => [],
                                                  'vars' => ''
                                                }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'BNAME' => bless( {
                                                  'line' => 70,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'error' => undef,
                                                                        'line' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'description' => '/[A-Z]\\\\w*::/',
                                                                                              'mod' => '',
                                                                                              'rdelim' => '/',
                                                                                              'ldelim' => '/',
                                                                                              'line' => 71,
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'lookahead' => 0,
                                                                                              'pattern' => '[A-Z]\\w*::'
                                                                                            }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                     bless( {
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'matchrule' => 0,
                                                                                              'line' => 71,
                                                                                              'subrule' => 'BNAME',
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'code' => '{$return = $item[1].$item[2]}',
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'line' => 71,
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'number' => 0,
                                                                        'uncommit' => undef,
                                                                        'actcount' => 1,
                                                                        'patcount' => 1
                                                                      }, 'Parse::RecDescent::_Runtime::Production' ),
                                                               bless( {
                                                                        'number' => 1,
                                                                        'uncommit' => undef,
                                                                        'actcount' => 1,
                                                                        'patcount' => 1,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'error' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'ldelim' => '/',
                                                                                              'pattern' => '[A-Z]\\w*',
                                                                                              'lookahead' => 0,
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'line' => 72,
                                                                                              'description' => '/[A-Z]\\\\w*/',
                                                                                              'rdelim' => '/',
                                                                                              'mod' => ''
                                                                                            }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                     bless( {
                                                                                              'lookahead' => 0,
                                                                                              'line' => 72,
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'code' => '{$return = $item[1]}'
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'line' => undef
                                                                      }, 'Parse::RecDescent::_Runtime::Production' )
                                                             ],
                                                  'vars' => '',
                                                  'name' => 'BNAME',
                                                  'impcount' => 0,
                                                  'calls' => [
                                                               'BNAME'
                                                             ],
                                                  'changed' => 0
                                                }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'SLASHEDDQUOTE' => bless( {
                                                          'name' => 'SLASHEDDQUOTE',
                                                          'impcount' => 0,
                                                          'calls' => [],
                                                          'changed' => 0,
                                                          'vars' => '',
                                                          'line' => 88,
                                                          'opcount' => 0,
                                                          'prods' => [
                                                                       bless( {
                                                                                'line' => undef,
                                                                                'items' => [
                                                                                             bless( {
                                                                                                      'pattern' => '\\\\"',
                                                                                                      'lookahead' => 0,
                                                                                                      'line' => 88,
                                                                                                      'hashname' => '__PATTERN1__',
                                                                                                      'ldelim' => '/',
                                                                                                      'rdelim' => '/',
                                                                                                      'mod' => '',
                                                                                                      'description' => '/\\\\\\\\"/'
                                                                                                    }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                             bless( {
                                                                                                      'code' => '{$return = \'"\'}',
                                                                                                      'lookahead' => 0,
                                                                                                      'line' => 88,
                                                                                                      'hashname' => '__ACTION1__'
                                                                                                    }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                           ],
                                                                                'error' => undef,
                                                                                'dircount' => 0,
                                                                                'strcount' => 0,
                                                                                'actcount' => 1,
                                                                                'patcount' => 1,
                                                                                'uncommit' => undef,
                                                                                'number' => 0
                                                                              }, 'Parse::RecDescent::_Runtime::Production' )
                                                                     ]
                                                        }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'NOTDQUOTE' => bless( {
                                                      'line' => 87,
                                                      'opcount' => 0,
                                                      'prods' => [
                                                                   bless( {
                                                                            'error' => undef,
                                                                            'dircount' => 0,
                                                                            'line' => undef,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'line' => 87,
                                                                                                  'hashname' => '__PATTERN1__',
                                                                                                  'pattern' => '[^"]*[^"\\\\]',
                                                                                                  'lookahead' => 0,
                                                                                                  'ldelim' => '/',
                                                                                                  'mod' => '',
                                                                                                  'rdelim' => '/',
                                                                                                  'description' => '/[^"]*[^"\\\\\\\\]/'
                                                                                                }, 'Parse::RecDescent::_Runtime::Token' )
                                                                                       ],
                                                                            'strcount' => 0,
                                                                            'patcount' => 1,
                                                                            'actcount' => 0,
                                                                            'number' => 0,
                                                                            'uncommit' => undef
                                                                          }, 'Parse::RecDescent::_Runtime::Production' )
                                                                 ],
                                                      'name' => 'NOTDQUOTE',
                                                      'impcount' => 0,
                                                      'calls' => [],
                                                      'changed' => 0,
                                                      'vars' => ''
                                                    }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'NOTSQUOTE' => bless( {
                                                      'calls' => [],
                                                      'changed' => 0,
                                                      'impcount' => 0,
                                                      'name' => 'NOTSQUOTE',
                                                      'vars' => '',
                                                      'prods' => [
                                                                   bless( {
                                                                            'dircount' => 0,
                                                                            'error' => undef,
                                                                            'line' => undef,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'rdelim' => '/',
                                                                                                  'mod' => '',
                                                                                                  'description' => '/[^\']*[^\'\\\\\\\\]/',
                                                                                                  'pattern' => '[^\']*[^\'\\\\]',
                                                                                                  'lookahead' => 0,
                                                                                                  'hashname' => '__PATTERN1__',
                                                                                                  'line' => 83,
                                                                                                  'ldelim' => '/'
                                                                                                }, 'Parse::RecDescent::_Runtime::Token' )
                                                                                       ],
                                                                            'strcount' => 0,
                                                                            'actcount' => 0,
                                                                            'patcount' => 1,
                                                                            'number' => 0,
                                                                            'uncommit' => undef
                                                                          }, 'Parse::RecDescent::_Runtime::Production' )
                                                                 ],
                                                      'opcount' => 0,
                                                      'line' => 83
                                                    }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'INCLUDE' => bless( {
                                                    'prods' => [
                                                                 bless( {
                                                                          'actcount' => 1,
                                                                          'patcount' => 1,
                                                                          'uncommit' => undef,
                                                                          'number' => 0,
                                                                          'line' => undef,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'description' => '/\\\\/\\\\S+\\\\.scen/',
                                                                                                'mod' => '',
                                                                                                'rdelim' => '/',
                                                                                                'ldelim' => '/',
                                                                                                'line' => 61,
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'lookahead' => 0,
                                                                                                'pattern' => '\\/\\S+\\.scen'
                                                                                              }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                       bless( {
                                                                                                'code' => '{$return = $item[1]}',
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'line' => 61,
                                                                                                'lookahead' => 0
                                                                                              }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                     ],
                                                                          'error' => undef,
                                                                          'dircount' => 0,
                                                                          'strcount' => 0
                                                                        }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                 bless( {
                                                                          'error' => undef,
                                                                          'dircount' => 0,
                                                                          'line' => undef,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'description' => '/[^\\\\/#]\\\\S+\\\\.scen/',
                                                                                                'rdelim' => '/',
                                                                                                'mod' => '',
                                                                                                'ldelim' => '/',
                                                                                                'lookahead' => 0,
                                                                                                'pattern' => '[^\\/#]\\S+\\.scen',
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'line' => 62
                                                                                              }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                       bless( {
                                                                                                'code' => '{   my $from_file = $arg[0];
                                                    if (length $from_file) {
                                                        $return = dirname($from_file) . "/$item[1]";
                                                    } else {
                                                        $return = "./$item[1]";
                                                    }
                                                }',
                                                                                                'line' => 62,
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0
                                                                                              }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                     ],
                                                                          'strcount' => 0,
                                                                          'actcount' => 1,
                                                                          'patcount' => 1,
                                                                          'number' => 1,
                                                                          'uncommit' => undef
                                                                        }, 'Parse::RecDescent::_Runtime::Production' )
                                                               ],
                                                    'opcount' => 0,
                                                    'line' => 61,
                                                    'vars' => '',
                                                    'changed' => 0,
                                                    'calls' => [],
                                                    'impcount' => 0,
                                                    'name' => 'INCLUDE'
                                                  }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'EOF' => bless( {
                                                'prods' => [
                                                             bless( {
                                                                      'patcount' => 1,
                                                                      'actcount' => 0,
                                                                      'uncommit' => undef,
                                                                      'number' => 0,
                                                                      'items' => [
                                                                                   bless( {
                                                                                            'description' => '/^\\\\Z/',
                                                                                            'mod' => '',
                                                                                            'rdelim' => '/',
                                                                                            'ldelim' => '/',
                                                                                            'line' => 15,
                                                                                            'hashname' => '__PATTERN1__',
                                                                                            'pattern' => '^\\Z',
                                                                                            'lookahead' => 0
                                                                                          }, 'Parse::RecDescent::_Runtime::Token' )
                                                                                 ],
                                                                      'line' => undef,
                                                                      'error' => undef,
                                                                      'dircount' => 0,
                                                                      'strcount' => 0
                                                                    }, 'Parse::RecDescent::_Runtime::Production' )
                                                           ],
                                                'line' => 15,
                                                'opcount' => 0,
                                                'impcount' => 0,
                                                'calls' => [],
                                                'changed' => 0,
                                                'name' => 'EOF',
                                                'vars' => ''
                                              }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'PTICKED' => bless( {
                                                    'name' => 'PTICKED',
                                                    'changed' => 0,
                                                    'calls' => [],
                                                    'impcount' => 0,
                                                    'vars' => '',
                                                    'opcount' => 0,
                                                    'line' => 92,
                                                    'prods' => [
                                                                 bless( {
                                                                          'line' => undef,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'ldelim' => '/',
                                                                                                'pattern' => '[^`]+',
                                                                                                'lookahead' => 0,
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'line' => 92,
                                                                                                'description' => '/[^`]+/',
                                                                                                'rdelim' => '/',
                                                                                                'mod' => ''
                                                                                              }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                       bless( {
                                                                                                'line' => 92,
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'lookahead' => 0,
                                                                                                'code' => '{$return = $item[1]}'
                                                                                              }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                     ],
                                                                          'error' => undef,
                                                                          'dircount' => 0,
                                                                          'strcount' => 0,
                                                                          'patcount' => 1,
                                                                          'actcount' => 1,
                                                                          'uncommit' => undef,
                                                                          'number' => 0
                                                                        }, 'Parse::RecDescent::_Runtime::Production' )
                                                               ]
                                                  }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'SPACE' => bless( {
                                                  'vars' => '',
                                                  'name' => 'SPACE',
                                                  'impcount' => 0,
                                                  'changed' => 0,
                                                  'calls' => [],
                                                  'line' => 94,
                                                  'opcount' => 0,
                                                  'prods' => [
                                                               bless( {
                                                                        'strcount' => 0,
                                                                        'line' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'rdelim' => '/',
                                                                                              'mod' => '',
                                                                                              'description' => '/\\\\s+/',
                                                                                              'pattern' => '\\s+',
                                                                                              'lookahead' => 0,
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'line' => 94,
                                                                                              'ldelim' => '/'
                                                                                            }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                     bless( {
                                                                                              'code' => '{$return = $item[1]}',
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'line' => 94,
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'dircount' => 0,
                                                                        'error' => undef,
                                                                        'uncommit' => undef,
                                                                        'number' => 0,
                                                                        'actcount' => 1,
                                                                        'patcount' => 1
                                                                      }, 'Parse::RecDescent::_Runtime::Production' )
                                                             ]
                                                }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'TBNAME' => bless( {
                                                   'impcount' => 0,
                                                   'calls' => [
                                                                'BNAME'
                                                              ],
                                                   'changed' => 0,
                                                   'name' => 'TBNAME',
                                                   'vars' => '',
                                                   'prods' => [
                                                                bless( {
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'error' => undef,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'line' => 69,
                                                                                               'lookahead' => 0,
                                                                                               'pattern' => '::',
                                                                                               'ldelim' => '/',
                                                                                               'mod' => '',
                                                                                               'rdelim' => '/',
                                                                                               'description' => '/::/'
                                                                                             }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                      bless( {
                                                                                               'matchrule' => 0,
                                                                                               'line' => 69,
                                                                                               'subrule' => 'BNAME',
                                                                                               'lookahead' => 0,
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'code' => '{$return = $item{BNAME}}',
                                                                                               'lookahead' => 0,
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'line' => 69
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'line' => undef,
                                                                         'number' => 0,
                                                                         'uncommit' => undef,
                                                                         'actcount' => 1,
                                                                         'patcount' => 1
                                                                       }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                bless( {
                                                                         'number' => 1,
                                                                         'uncommit' => undef,
                                                                         'actcount' => 1,
                                                                         'patcount' => 0,
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'error' => undef,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'argcode' => undef,
                                                                                               'implicit' => undef,
                                                                                               'line' => 70,
                                                                                               'subrule' => 'BNAME',
                                                                                               'lookahead' => 0,
                                                                                               'matchrule' => 0
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'code' => '{$return = "Treex::Block::$item{BNAME}"}',
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'line' => 70,
                                                                                               'lookahead' => 0
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'line' => undef
                                                                       }, 'Parse::RecDescent::_Runtime::Production' )
                                                              ],
                                                   'line' => 69,
                                                   'opcount' => 0
                                                 }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'BLOCK' => bless( {
                                                  'vars' => '',
                                                  'impcount' => 0,
                                                  'changed' => 0,
                                                  'calls' => [
                                                               'INCLUDE',
                                                               'SCENMODULE',
                                                               'PARAMS',
                                                               'TBNAME'
                                                             ],
                                                  'name' => 'BLOCK',
                                                  'prods' => [
                                                               bless( {
                                                                        'number' => 0,
                                                                        'uncommit' => undef,
                                                                        'patcount' => 0,
                                                                        'actcount' => 1,
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'error' => undef,
                                                                        'line' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef,
                                                                                              'matchrule' => 0,
                                                                                              'line' => 16,
                                                                                              'subrule' => 'INCLUDE',
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'code' => '{
                                                    my $included = read_file( $item{INCLUDE}, binmode => \':utf8\' );
                                                    my $result = $thisparser->startrule( $included, 1, $item{INCLUDE} );
                                                    if (defined $result and ref $result eq \'ARRAY\') {
                                                        $return = [@$result];
                                                    } else {
                                                        $return = undef;
                                                    }
                                                }',
                                                                                              'line' => 16,
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ]
                                                                      }, 'Parse::RecDescent::_Runtime::Production' ),
                                                               bless( {
                                                                        'patcount' => 0,
                                                                        'actcount' => 1,
                                                                        'uncommit' => undef,
                                                                        'number' => 1,
                                                                        'line' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'matchrule' => 0,
                                                                                              'line' => 25,
                                                                                              'lookahead' => 0,
                                                                                              'subrule' => 'SCENMODULE',
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'matchrule' => 0,
                                                                                              'line' => 25,
                                                                                              'subrule' => 'PARAMS',
                                                                                              'lookahead' => 0,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'lookahead' => 0,
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'line' => 25,
                                                                                              'code' => '{
                                                    my $modulename = $item{SCENMODULE};
                                                    eval "use $modulename; 1;" or die "Can\'t use $modulename !\\n$@\\n";
                                                    my %params = map {my ($name,$value) = split /=/, $_, 2; ($name, $value)} @{$item{PARAMS}};
                                                    my $scenmod = $modulename->new(\\%params);
                                                    my $string = $scenmod->get_scenario_string();
                                                    my $result = $thisparser->startrule( $string, 0, \'\' );
                                                    if (defined $result and ref $result eq \'ARRAY\') {
                                                        $return = [@$result];
                                                    } else {
                                                        log_fatal "Syntax error in \'$modulename\' scenario:\\n<BEGIN SCENARIO>\\n$string\\n<END SCENARIO>";
                                                    }
                                                }'
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'error' => undef,
                                                                        'dircount' => 0,
                                                                        'strcount' => 0
                                                                      }, 'Parse::RecDescent::_Runtime::Production' ),
                                                               bless( {
                                                                        'actcount' => 1,
                                                                        'patcount' => 0,
                                                                        'uncommit' => undef,
                                                                        'number' => 2,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'matchrule' => 0,
                                                                                              'lookahead' => 0,
                                                                                              'subrule' => 'SCENMODULE',
                                                                                              'line' => 38,
                                                                                              'implicit' => undef,
                                                                                              'argcode' => undef
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'line' => 38,
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'lookahead' => 0,
                                                                                              'code' => '{
                                                    my $modulename = $item{SCENMODULE};
                                                    eval "use $modulename; 1;" or die "Can\'t use $modulename !\\n$@\\n";
                                                    my $scenmod = $modulename->new();
                                                    my $string = $scenmod->get_scenario_string();
                                                    my $result = $thisparser->startrule( $string, 0, \'\' );
                                                    if (defined $result and ref $result eq \'ARRAY\') {
                                                        $return = [@$result];
                                                    } else {
                                                        log_fatal "Syntax error in \'$modulename\' scenario:\\n<BEGIN SCENARIO>\\n$string\\n<END SCENARIO>";
                                                    }
                                                }'
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'line' => undef,
                                                                        'error' => undef,
                                                                        'dircount' => 0,
                                                                        'strcount' => 0
                                                                      }, 'Parse::RecDescent::_Runtime::Production' ),
                                                               bless( {
                                                                        'uncommit' => undef,
                                                                        'number' => 3,
                                                                        'actcount' => 1,
                                                                        'patcount' => 0,
                                                                        'strcount' => 0,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'argcode' => undef,
                                                                                              'implicit' => undef,
                                                                                              'line' => 50,
                                                                                              'subrule' => 'TBNAME',
                                                                                              'lookahead' => 0,
                                                                                              'matchrule' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'line' => 50,
                                                                                              'subrule' => 'PARAMS',
                                                                                              'lookahead' => 0,
                                                                                              'matchrule' => 0,
                                                                                              'argcode' => undef,
                                                                                              'implicit' => undef
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'code' => '{$return = [{
                                                        block_name=>$item{TBNAME},
                                                        block_parameters=>$item{PARAMS},
                                                    }]
                                                }',
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'line' => 50,
                                                                                              'lookahead' => 0
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'line' => undef,
                                                                        'error' => undef,
                                                                        'dircount' => 0
                                                                      }, 'Parse::RecDescent::_Runtime::Production' ),
                                                               bless( {
                                                                        'strcount' => 0,
                                                                        'dircount' => 0,
                                                                        'error' => undef,
                                                                        'line' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'line' => 55,
                                                                                              'subrule' => 'TBNAME',
                                                                                              'lookahead' => 0,
                                                                                              'matchrule' => 0,
                                                                                              'argcode' => undef,
                                                                                              'implicit' => undef
                                                                                            }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                     bless( {
                                                                                              'lookahead' => 0,
                                                                                              'line' => 55,
                                                                                              'hashname' => '__ACTION1__',
                                                                                              'code' => '{$return = [{
                                                        block_name=>$item{TBNAME},
                                                        block_parameters=>[],
                                                    }]
                                                }'
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'number' => 4,
                                                                        'uncommit' => undef,
                                                                        'actcount' => 1,
                                                                        'patcount' => 0
                                                                      }, 'Parse::RecDescent::_Runtime::Production' )
                                                             ],
                                                  'line' => 16,
                                                  'opcount' => 0
                                                }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'COMMENT' => bless( {
                                                    'calls' => [],
                                                    'changed' => 0,
                                                    'impcount' => 0,
                                                    'name' => 'COMMENT',
                                                    'vars' => '',
                                                    'prods' => [
                                                                 bless( {
                                                                          'error' => undef,
                                                                          'dircount' => 0,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'mod' => '',
                                                                                                'rdelim' => '/',
                                                                                                'description' => '/#[^\\\\n]*/',
                                                                                                'line' => 93,
                                                                                                'hashname' => '__PATTERN1__',
                                                                                                'pattern' => '#[^\\n]*',
                                                                                                'lookahead' => 0,
                                                                                                'ldelim' => '/'
                                                                                              }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'line' => 93,
                                                                                                'lookahead' => 0,
                                                                                                'code' => '{$return = \'\'}'
                                                                                              }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                     ],
                                                                          'line' => undef,
                                                                          'strcount' => 0,
                                                                          'actcount' => 1,
                                                                          'patcount' => 1,
                                                                          'number' => 0,
                                                                          'uncommit' => undef
                                                                        }, 'Parse::RecDescent::_Runtime::Production' )
                                                               ],
                                                    'opcount' => 0,
                                                    'line' => 93
                                                  }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'startrule' => bless( {
                                                      'name' => 'startrule',
                                                      'calls' => [
                                                                   'SCEN',
                                                                   'EOF'
                                                                 ],
                                                      'changed' => 0,
                                                      'impcount' => 0,
                                                      'vars' => '',
                                                      'opcount' => 0,
                                                      'line' => 9,
                                                      'prods' => [
                                                                   bless( {
                                                                            'uncommit' => undef,
                                                                            'number' => 0,
                                                                            'patcount' => 0,
                                                                            'actcount' => 1,
                                                                            'strcount' => 0,
                                                                            'items' => [
                                                                                         bless( {
                                                                                                  'lookahead' => 0,
                                                                                                  'subrule' => 'SCEN',
                                                                                                  'line' => 9,
                                                                                                  'matchrule' => 0,
                                                                                                  'argcode' => undef,
                                                                                                  'implicit' => undef
                                                                                                }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                         bless( {
                                                                                                  'implicit' => undef,
                                                                                                  'argcode' => undef,
                                                                                                  'matchrule' => 0,
                                                                                                  'subrule' => 'EOF',
                                                                                                  'lookahead' => 0,
                                                                                                  'line' => 9
                                                                                                }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                         bless( {
                                                                                                  'hashname' => '__ACTION1__',
                                                                                                  'line' => 9,
                                                                                                  'lookahead' => 0,
                                                                                                  'code' => '{$return = $item{SCEN}}'
                                                                                                }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                       ],
                                                                            'line' => undef,
                                                                            'error' => undef,
                                                                            'dircount' => 0
                                                                          }, 'Parse::RecDescent::_Runtime::Production' )
                                                                 ]
                                                    }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'SCEN' => bless( {
                                                 'changed' => 0,
                                                 'calls' => [
                                                              'LINE',
                                                              'SCEN'
                                                            ],
                                                 'impcount' => 0,
                                                 'name' => 'SCEN',
                                                 'vars' => '',
                                                 'prods' => [
                                                              bless( {
                                                                       'patcount' => 0,
                                                                       'actcount' => 1,
                                                                       'number' => 0,
                                                                       'uncommit' => undef,
                                                                       'error' => undef,
                                                                       'dircount' => 0,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'line' => 10,
                                                                                             'lookahead' => 0,
                                                                                             'subrule' => 'LINE',
                                                                                             'matchrule' => 0,
                                                                                             'argcode' => undef,
                                                                                             'implicit' => undef
                                                                                           }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                    bless( {
                                                                                             'matchrule' => 0,
                                                                                             'line' => 10,
                                                                                             'lookahead' => 0,
                                                                                             'subrule' => 'SCEN',
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef
                                                                                           }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                    bless( {
                                                                                             'code' => '{$return = [@{$item{LINE}},@{$item{SCEN}}]}',
                                                                                             'line' => 10,
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'lookahead' => 0
                                                                                           }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                  ],
                                                                       'line' => undef,
                                                                       'strcount' => 0
                                                                     }, 'Parse::RecDescent::_Runtime::Production' ),
                                                              bless( {
                                                                       'line' => undef,
                                                                       'items' => [
                                                                                    bless( {
                                                                                             'implicit' => undef,
                                                                                             'argcode' => undef,
                                                                                             'matchrule' => 0,
                                                                                             'line' => 11,
                                                                                             'subrule' => 'LINE',
                                                                                             'lookahead' => 0
                                                                                           }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                    bless( {
                                                                                             'lookahead' => 0,
                                                                                             'hashname' => '__ACTION1__',
                                                                                             'line' => 11,
                                                                                             'code' => '{$return = [@{$item{LINE}}]}'
                                                                                           }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                  ],
                                                                       'error' => undef,
                                                                       'dircount' => 0,
                                                                       'strcount' => 0,
                                                                       'actcount' => 1,
                                                                       'patcount' => 0,
                                                                       'uncommit' => undef,
                                                                       'number' => 1
                                                                     }, 'Parse::RecDescent::_Runtime::Production' )
                                                            ],
                                                 'opcount' => 0,
                                                 'line' => 10
                                               }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'SCENMODULE' => bless( {
                                                       'opcount' => 0,
                                                       'line' => 60,
                                                       'prods' => [
                                                                    bless( {
                                                                             'actcount' => 1,
                                                                             'patcount' => 1,
                                                                             'number' => 0,
                                                                             'uncommit' => undef,
                                                                             'dircount' => 0,
                                                                             'error' => undef,
                                                                             'items' => [
                                                                                          bless( {
                                                                                                   'lookahead' => 0,
                                                                                                   'pattern' => 'Scen::',
                                                                                                   'hashname' => '__PATTERN1__',
                                                                                                   'line' => 60,
                                                                                                   'ldelim' => '/',
                                                                                                   'rdelim' => '/',
                                                                                                   'mod' => '',
                                                                                                   'description' => '/Scen::/'
                                                                                                 }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                          bless( {
                                                                                                   'argcode' => undef,
                                                                                                   'implicit' => undef,
                                                                                                   'lookahead' => 0,
                                                                                                   'subrule' => 'BNAME',
                                                                                                   'line' => 60,
                                                                                                   'matchrule' => 0
                                                                                                 }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                          bless( {
                                                                                                   'code' => '{ $return = "Treex::Scen::$item{BNAME}"}',
                                                                                                   'hashname' => '__ACTION1__',
                                                                                                   'line' => 60,
                                                                                                   'lookahead' => 0
                                                                                                 }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                        ],
                                                                             'line' => undef,
                                                                             'strcount' => 0
                                                                           }, 'Parse::RecDescent::_Runtime::Production' )
                                                                  ],
                                                       'name' => 'SCENMODULE',
                                                       'calls' => [
                                                                    'BNAME'
                                                                  ],
                                                       'changed' => 0,
                                                       'impcount' => 0,
                                                       'vars' => ''
                                                     }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'PVALUE' => bless( {
                                                   'vars' => '',
                                                   'impcount' => 0,
                                                   'calls' => [
                                                                'PSQUOTE',
                                                                'PDQUOTE',
                                                                'PTICKED',
                                                                'PNOTQUOTED'
                                                              ],
                                                   'changed' => 0,
                                                   'name' => 'PVALUE',
                                                   'prods' => [
                                                                bless( {
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'error' => undef,
                                                                         'line' => undef,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'ldelim' => '/',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'line' => 77,
                                                                                               'lookahead' => 0,
                                                                                               'pattern' => '\'',
                                                                                               'description' => '/\'/',
                                                                                               'mod' => '',
                                                                                               'rdelim' => '/'
                                                                                             }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                      bless( {
                                                                                               'lookahead' => 0,
                                                                                               'subrule' => 'PSQUOTE',
                                                                                               'line' => 77,
                                                                                               'matchrule' => 0,
                                                                                               'argcode' => undef,
                                                                                               'implicit' => undef
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'mod' => '',
                                                                                               'rdelim' => '/',
                                                                                               'description' => '/\'/',
                                                                                               'hashname' => '__PATTERN2__',
                                                                                               'line' => 77,
                                                                                               'pattern' => '\'',
                                                                                               'lookahead' => 0,
                                                                                               'ldelim' => '/'
                                                                                             }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                      bless( {
                                                                                               'lookahead' => 0,
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'line' => 77,
                                                                                               'code' => '{$return = $item{PSQUOTE}}'
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'number' => 0,
                                                                         'uncommit' => undef,
                                                                         'actcount' => 1,
                                                                         'patcount' => 2
                                                                       }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                bless( {
                                                                         'strcount' => 0,
                                                                         'dircount' => 0,
                                                                         'error' => undef,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'description' => '/"/',
                                                                                               'mod' => '',
                                                                                               'rdelim' => '/',
                                                                                               'ldelim' => '/',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'line' => 78,
                                                                                               'pattern' => '"',
                                                                                               'lookahead' => 0
                                                                                             }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                      bless( {
                                                                                               'argcode' => undef,
                                                                                               'implicit' => undef,
                                                                                               'line' => 78,
                                                                                               'subrule' => 'PDQUOTE',
                                                                                               'lookahead' => 0,
                                                                                               'matchrule' => 0
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'hashname' => '__PATTERN2__',
                                                                                               'line' => 78,
                                                                                               'lookahead' => 0,
                                                                                               'pattern' => '"',
                                                                                               'ldelim' => '/',
                                                                                               'mod' => '',
                                                                                               'rdelim' => '/',
                                                                                               'description' => '/"/'
                                                                                             }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                      bless( {
                                                                                               'code' => '{$return = $item{PDQUOTE}}',
                                                                                               'line' => 78,
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'lookahead' => 0
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'line' => undef,
                                                                         'number' => 1,
                                                                         'uncommit' => undef,
                                                                         'patcount' => 2,
                                                                         'actcount' => 1
                                                                       }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                bless( {
                                                                         'uncommit' => undef,
                                                                         'number' => 2,
                                                                         'actcount' => 1,
                                                                         'patcount' => 2,
                                                                         'strcount' => 0,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'ldelim' => '/',
                                                                                               'lookahead' => 0,
                                                                                               'pattern' => '`',
                                                                                               'hashname' => '__PATTERN1__',
                                                                                               'line' => 79,
                                                                                               'description' => '/`/',
                                                                                               'rdelim' => '/',
                                                                                               'mod' => ''
                                                                                             }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                      bless( {
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'matchrule' => 0,
                                                                                               'line' => 79,
                                                                                               'lookahead' => 0,
                                                                                               'subrule' => 'PTICKED'
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'description' => '/`/',
                                                                                               'mod' => '',
                                                                                               'rdelim' => '/',
                                                                                               'ldelim' => '/',
                                                                                               'line' => 79,
                                                                                               'hashname' => '__PATTERN2__',
                                                                                               'lookahead' => 0,
                                                                                               'pattern' => '`'
                                                                                             }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                      bless( {
                                                                                               'lookahead' => 0,
                                                                                               'line' => 79,
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'code' => '{$return = $item[1].$item[2].$item[3]}'
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'line' => undef,
                                                                         'dircount' => 0,
                                                                         'error' => undef
                                                                       }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                bless( {
                                                                         'actcount' => 1,
                                                                         'patcount' => 0,
                                                                         'uncommit' => undef,
                                                                         'number' => 3,
                                                                         'line' => undef,
                                                                         'items' => [
                                                                                      bless( {
                                                                                               'implicit' => undef,
                                                                                               'argcode' => undef,
                                                                                               'matchrule' => 0,
                                                                                               'lookahead' => 0,
                                                                                               'subrule' => 'PNOTQUOTED',
                                                                                               'line' => 80
                                                                                             }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                      bless( {
                                                                                               'code' => '{$return = $item{PNOTQUOTED}}',
                                                                                               'lookahead' => 0,
                                                                                               'hashname' => '__ACTION1__',
                                                                                               'line' => 80
                                                                                             }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                    ],
                                                                         'dircount' => 0,
                                                                         'error' => undef,
                                                                         'strcount' => 0
                                                                       }, 'Parse::RecDescent::_Runtime::Production' )
                                                              ],
                                                   'line' => 77,
                                                   'opcount' => 0
                                                 }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'PSQUOTE' => bless( {
                                                    'opcount' => 0,
                                                    'line' => 81,
                                                    'prods' => [
                                                                 bless( {
                                                                          'actcount' => 1,
                                                                          'patcount' => 0,
                                                                          'number' => 0,
                                                                          'uncommit' => undef,
                                                                          'dircount' => 0,
                                                                          'error' => undef,
                                                                          'line' => undef,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'argcode' => undef,
                                                                                                'implicit' => undef,
                                                                                                'line' => 81,
                                                                                                'lookahead' => 0,
                                                                                                'subrule' => 'NOTSQUOTE',
                                                                                                'matchrule' => 0
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                       bless( {
                                                                                                'matchrule' => 0,
                                                                                                'lookahead' => 0,
                                                                                                'subrule' => 'SLASHEDSQUOTE',
                                                                                                'line' => 81,
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                       bless( {
                                                                                                'matchrule' => 0,
                                                                                                'line' => 81,
                                                                                                'subrule' => 'PSQUOTE',
                                                                                                'lookahead' => 0,
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                       bless( {
                                                                                                'code' => '{$return = $item{NOTSQUOTE}.$item{SLASHEDSQUOTE}.$item{PSQUOTE}}',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 81,
                                                                                                'hashname' => '__ACTION1__'
                                                                                              }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                     ],
                                                                          'strcount' => 0
                                                                        }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                 bless( {
                                                                          'patcount' => 0,
                                                                          'actcount' => 0,
                                                                          'number' => 1,
                                                                          'uncommit' => undef,
                                                                          'dircount' => 0,
                                                                          'error' => undef,
                                                                          'line' => undef,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'argcode' => undef,
                                                                                                'implicit' => undef,
                                                                                                'line' => 82,
                                                                                                'lookahead' => 0,
                                                                                                'subrule' => 'NOTSQUOTE',
                                                                                                'matchrule' => 0
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' )
                                                                                     ],
                                                                          'strcount' => 0
                                                                        }, 'Parse::RecDescent::_Runtime::Production' )
                                                               ],
                                                    'name' => 'PSQUOTE',
                                                    'changed' => 0,
                                                    'calls' => [
                                                                 'NOTSQUOTE',
                                                                 'SLASHEDSQUOTE',
                                                                 'PSQUOTE'
                                                               ],
                                                    'impcount' => 0,
                                                    'vars' => ''
                                                  }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'SLASHEDSQUOTE' => bless( {
                                                          'impcount' => 0,
                                                          'calls' => [],
                                                          'changed' => 0,
                                                          'name' => 'SLASHEDSQUOTE',
                                                          'vars' => '',
                                                          'prods' => [
                                                                       bless( {
                                                                                'strcount' => 0,
                                                                                'line' => undef,
                                                                                'items' => [
                                                                                             bless( {
                                                                                                      'ldelim' => '/',
                                                                                                      'hashname' => '__PATTERN1__',
                                                                                                      'line' => 84,
                                                                                                      'pattern' => '\\\\\'',
                                                                                                      'lookahead' => 0,
                                                                                                      'description' => '/\\\\\\\\\'/',
                                                                                                      'mod' => '',
                                                                                                      'rdelim' => '/'
                                                                                                    }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                             bless( {
                                                                                                      'hashname' => '__ACTION1__',
                                                                                                      'line' => 84,
                                                                                                      'lookahead' => 0,
                                                                                                      'code' => '{$return = "\'"}'
                                                                                                    }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                           ],
                                                                                'dircount' => 0,
                                                                                'error' => undef,
                                                                                'uncommit' => undef,
                                                                                'number' => 0,
                                                                                'patcount' => 1,
                                                                                'actcount' => 1
                                                                              }, 'Parse::RecDescent::_Runtime::Production' )
                                                                     ],
                                                          'line' => 84,
                                                          'opcount' => 0
                                                        }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'PNAME' => bless( {
                                                  'vars' => '',
                                                  'impcount' => 0,
                                                  'calls' => [],
                                                  'changed' => 0,
                                                  'name' => 'PNAME',
                                                  'prods' => [
                                                               bless( {
                                                                        'uncommit' => undef,
                                                                        'number' => 0,
                                                                        'actcount' => 1,
                                                                        'patcount' => 1,
                                                                        'strcount' => 0,
                                                                        'line' => undef,
                                                                        'items' => [
                                                                                     bless( {
                                                                                              'line' => 76,
                                                                                              'hashname' => '__PATTERN1__',
                                                                                              'pattern' => '\\w+',
                                                                                              'lookahead' => 0,
                                                                                              'ldelim' => '/',
                                                                                              'mod' => '',
                                                                                              'rdelim' => '/',
                                                                                              'description' => '/\\\\w+/'
                                                                                            }, 'Parse::RecDescent::_Runtime::Token' ),
                                                                                     bless( {
                                                                                              'code' => '{$return = $item[1]}',
                                                                                              'lookahead' => 0,
                                                                                              'line' => 76,
                                                                                              'hashname' => '__ACTION1__'
                                                                                            }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                   ],
                                                                        'error' => undef,
                                                                        'dircount' => 0
                                                                      }, 'Parse::RecDescent::_Runtime::Production' )
                                                             ],
                                                  'line' => 76,
                                                  'opcount' => 0
                                                }, 'Parse::RecDescent::_Runtime::Rule' ),
                              'PDQUOTE' => bless( {
                                                    'calls' => [
                                                                 'NOTDQUOTE',
                                                                 'SLASHEDDQUOTE',
                                                                 'PDQUOTE'
                                                               ],
                                                    'changed' => 0,
                                                    'impcount' => 0,
                                                    'name' => 'PDQUOTE',
                                                    'vars' => '',
                                                    'prods' => [
                                                                 bless( {
                                                                          'dircount' => 0,
                                                                          'error' => undef,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'subrule' => 'NOTDQUOTE',
                                                                                                'lookahead' => 0,
                                                                                                'line' => 85,
                                                                                                'matchrule' => 0,
                                                                                                'argcode' => undef,
                                                                                                'implicit' => undef
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                       bless( {
                                                                                                'implicit' => undef,
                                                                                                'argcode' => undef,
                                                                                                'matchrule' => 0,
                                                                                                'lookahead' => 0,
                                                                                                'subrule' => 'SLASHEDDQUOTE',
                                                                                                'line' => 85
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                       bless( {
                                                                                                'argcode' => undef,
                                                                                                'implicit' => undef,
                                                                                                'line' => 85,
                                                                                                'subrule' => 'PDQUOTE',
                                                                                                'lookahead' => 0,
                                                                                                'matchrule' => 0
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' ),
                                                                                       bless( {
                                                                                                'hashname' => '__ACTION1__',
                                                                                                'line' => 85,
                                                                                                'lookahead' => 0,
                                                                                                'code' => '{$return = $item{NOTDQUOTE}.$item{SLASHEDDQUOTE}.$item{PDQUOTE}}'
                                                                                              }, 'Parse::RecDescent::_Runtime::Action' )
                                                                                     ],
                                                                          'line' => undef,
                                                                          'strcount' => 0,
                                                                          'patcount' => 0,
                                                                          'actcount' => 1,
                                                                          'number' => 0,
                                                                          'uncommit' => undef
                                                                        }, 'Parse::RecDescent::_Runtime::Production' ),
                                                                 bless( {
                                                                          'strcount' => 0,
                                                                          'items' => [
                                                                                       bless( {
                                                                                                'line' => 86,
                                                                                                'subrule' => 'NOTDQUOTE',
                                                                                                'lookahead' => 0,
                                                                                                'matchrule' => 0,
                                                                                                'argcode' => undef,
                                                                                                'implicit' => undef
                                                                                              }, 'Parse::RecDescent::_Runtime::Subrule' )
                                                                                     ],
                                                                          'line' => undef,
                                                                          'dircount' => 0,
                                                                          'error' => undef,
                                                                          'uncommit' => undef,
                                                                          'number' => 1,
                                                                          'actcount' => 0,
                                                                          'patcount' => 0
                                                                        }, 'Parse::RecDescent::_Runtime::Production' )
                                                               ],
                                                    'opcount' => 0,
                                                    'line' => 85
                                                  }, 'Parse::RecDescent::_Runtime::Rule' )
                            },
                 '_AUTOACTION' => undef,
                 'startcode' => '',
                 '_check' => {
                               'prevline' => '',
                               'prevoffset' => '',
                               'thiscolumn' => '',
                               'thisoffset' => '',
                               'prevcolumn' => '',
                               'itempos' => ''
                             },
                 '_AUTOTREE' => undef,
                 'namespace' => 'Parse::RecDescent::_Runtime::Treex::Core::ScenarioParser',
                 'localvars' => ''
               }, 'Parse::RecDescent::_Runtime' );
}

