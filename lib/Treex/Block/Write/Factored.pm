package Treex::Block::Write::Factored;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

has to_attribute => ( isa => 'Str', is => 'ro', default => undef );

has outcols => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'SCzechM',
    documentation => 'The columns to emit.',
);


use Scalar::Util qw(reftype);
# use Data::Dumper;

my $allow_links_to_different_sentences = 1;
        # manual t-trees sometimes contain added nodes that *had* a
        # corresponding a-node in the *previous* sentence.
        # We cannot represent cross-sentence aux/lex.rf links so we
        # can either die or ignore such links.

### GetEChildren, modified from ./contrib/pml/PML_T.inc
# i.a. to return the sons grouped as grouped by coordination:
# Peter and I left the house and the country:
#  ( [Peter, I], [house, country] )
#
# It also includes common modifiers:
#   Peter (left and fell asleep):
#   left ---> [[Peter]]
#   fell ---> [[Peter], [asleep]]

sub IsCoord {
    my $node = $_[0];
    return 0 unless $node;
    return $node->get_attr('m/tag') eq "CC";
}

sub flatten {
    my $listref = shift;
    if ( ref($listref) eq "ARRAY" ) {
        return map { flatten($_) } (@$listref);
    }
    return $listref;
}

sub _FilterEChildren {    # node suff from
    my ( $node, $suff, $from ) = ( shift, shift, shift );
    my @sons;

    # $node=$node->firstson;
    foreach my $node ( $node->get_children ) {

        #    return @sons if $suff && @sons; #uncomment this line to get only first occurence
        unless ( $node == $from ) {    # on the way up do not go back down again
            my @thissons = ();
            if (( $suff && $node->get_attr('is_member') )
                || ( !$suff && !$node->get_attr('is_member') )
                )
            {                          # this we are looking for
                push @thissons, $node unless IsCoord($node);
            }
            push @thissons, _FilterEChildren( $node, 1, 0 )
                if (
                !$suff
                && IsCoord($node)
                && !$node->get_attr('is_member')
                )
                or (
                $suff
                && IsCoord($node)
                && $node->get_attr('is_member')
                );
            push @sons, [ flatten( \@thissons ) ]
                if 0 < scalar @thissons;    # add the songroup
        }    # unless node == from
             # $node=$node->rbrother;
    }
    @sons;
}    # _FilterEChildren

sub GetEChildren {    # node
    my $node = $_[0];
    return () if IsCoord($node);
    my @sons;
    my $init_node = $node;    # for error message
    my $from;
    push @sons, _FilterEChildren( $node, 0, 0 );
    if ( $node->get_attr('is_member') ) {

        # print STDERR "ISMEMBER: ".$node->get_attr('m/form')."\n";
        # print STDERR "nodetype: ".$node->get_attr('nodetype')."\n";
        my @oldsons = @sons;
        while (
            $node

            #and defined $node->get_attr('nodetype')
            #and $node->get_attr('nodetype')ne'root'
            and ( $node->get_attr('is_member') || !IsCoord($node) )
            )
        {
            $from = $node;
            $node = $node->get_parent;
            push @sons, _FilterEChildren( $node, 0, $from ) if $node;
        }

        # Ignore the following safety check...
        #if (defined $node->get_attr('nodetype')
        #    and $node->get_attr('nodetype')eq'root'){
        #  stderr("Error: Missing coordination head: $init_node->{id} $node->{id} ",ThisAddressNTRED($node),"\n");
        #  @sons=@oldsons;
        #}
    }
    @sons;
}    # GetEChildren

sub get_tree_name {
  # return tree name of a given node
  my $node = shift;
  my $root = $node->get_root();
  my $bundle = $node->get_bundle();
  my ($tree_name) = grep {$bundle->get_tree($_) == $root} $bundle->get_tree_names();
  return $tree_name;
}

sub preprocessor_for_at_output {
  # construct aidtotid map
  my $aroot = shift;
  my $aidtotid = undef;
  my $bundle = $aroot->get_bundle();
  my $doc = $aroot->get_document();
  my $ttreename = get_tree_name($aroot);
  $ttreename =~ s/A$/T/; # use the corresponding t-tree
  my $troot = $bundle->get_tree($ttreename);
  Report::fatal "Failed to get $ttreename for ".$bundle->get_attr('id')
    if ! defined $troot;
  foreach my $tnode ($troot->get_descendants) {
    my $links = $tnode->get_attr("a/lex.rf");
    if ( ref($links) eq "" ) {
        if ( !defined $links || $links eq "" ) {
            $links = [];
        }
        else {
            $links = [$links];
        }
    } elsif ( reftype($links) eq "ARRAY" ) {
        $links = [ $links->values() ];
    } else {
        Report::fatal "Unexpected links type: " . ref($links)
    }
    Report::fatal "More than one lex.rf at "
      .$tnode->get_attr('id')
      if 1 < scalar @$links;
    if (1 == scalar @$links) {
      my $aid = $links->[0];
      my $tid = $tnode->get_attr('id');
      Report::fatal "Two t-nodes point to the same a-node $aid: "
        ."$tid vs. $aidtotid->{$aid}"
        if defined $aidtotid->{$aid};
      $aidtotid->{$aid} = $tid;
    }
  }
  return $aidtotid;
}

sub producer_of_at_output {
  my $n = shift;
  my $aidtotid = shift;
  my $aid = $n->get_attr('id');
  my $tid = $aidtotid->{$aid};
  my $tnode = undef;
  if (defined $tid) {
    my $doc = $n->get_document();
    $tnode = $doc->get_node_by_id($tid);
  }
  return [
      $n->get_attr('m/form'),
      $n->get_attr('m/lemma'),
      $n->get_attr('m/tag'),
      $n->get_attr('ord'),
      ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
      $n->get_attr('afun'),
      ( # a sequence of t-layer attributes
      map {
        my $o = $tnode->get_attr($_) if defined $tnode;
        $o = "-" if ! defined $o;
        $o;
        }
        ( "t_lemma", "functor", "nodetype",
          "formeme", "gram/sempos",
        )
      )
  ];
}

my $export_rules = {
    "CzechW" => {  # Czech w-layer
        "treename" => "CzechM",
        "sort"    => undef,
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
            ];
        },
    },
    "CzechM" => {  # Czech m-layer
        "sort"    => undef,
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
            ];
        },
    },
    "CzechA" => {  # Czech a-layer, more or less canonic
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('m/form'),
                $n->get_attr('m/lemma'),
                $n->get_attr('m/tag'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
                $n->get_attr('afun'),
            ];
        },
    },
    "CzechAT" => {  # Czech a-layer with additional attributes from t-layer (via lex.rf)
        "treename" => "CzechA",
        "sort"    => "ord",
        "preprocessor" => sub { &preprocessor_for_at_output },
        "factors" => sub { &producer_of_at_output },
    },
    "EnglishM" => {
        # "sort"    => "ord",  # no ord attribute, preserve original order
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
            ];
        },
    },
    "EnglishA" => {
        "sort"              => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('m/form'),
                $n->get_attr('m/lemma'),
                $n->get_attr('m/tag'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
                $n->get_attr('afun'),
            ];
        },
    },
    "EnglishAT" => {  # English a-layer with additional attributes from t-layer (via lex.rf)
        "treename" => "EnglishA",
        "sort"    => "ord",
        "preprocessor" => sub { &preprocessor_for_at_output },
        "factors" => sub { &producer_of_at_output },
    },
    "EnglishAvalem" => {
        "sort"              => "ord",
        "top_down_modifier" => sub {
            my $n = shift;
            my $p = $n->get_parent;
            return if !defined $p;    # don't set anything for the root

            ## set valem, a factor describing the relation of a dependent
            ## towards the head
            my $valem       = "-";
            my $simplevalem = "-";
            my $lemma       = $n->get_attr('m/lemma');
            my $form        = $n->get_attr('m/form');
            my $tag         = $n->get_attr('m/tag');
            die "undefined $lemma, $form, $tag, id:" . $n->get_attr('id') if !defined $tag;
            if ( defined $p ) {
                my $plemma       = $p->get_attr('m/lemma')     || "-";       # for the root
                my $ptag         = $p->get_attr('m/tag')       || "-";
                my $pvalem       = $p->get_attr('valem')       || "-";
                my $psimplevalem = $p->get_attr('simplevalem') || $pvalem;
                $valem = $plemma if $ptag =~ /^(IN|TO|RB)$/;
                $valem = $lemma  if $tag  =~ /^(IN|TO|RB)$/;

                # prepositions set valem
                if (
                    (      $tag eq "DT"
                        || $tag eq "JJ"
                        || $tag eq "CC"
                        || $tag eq "PRP\$" || $tag eq "PDT" || $tag eq "CD"
                        || ( $tag eq "VBN" && $ptag =~ /^N/ )
                    )

                    # adjectives/articles/conjs/verbs under nouns
                    # inherit valem from father
                    || ( $tag eq "NNP" && $ptag eq "NNP" )

                    # proper noun under proper noun inherits!
                    || $ptag eq "CC"

                    # anything below a conj gets valem from the conj
                    )
                {
                    $valem       = $pvalem;
                    $simplevalem = $psimplevalem;
                }
                $valem = "N/N" if $tag =~ /^N/ && $ptag =~ /^N/;

                # noun under noun is a special "case"
            }
            if ( $tag =~ /^V/ || $tag eq "MD" ) {

                # verb assigns arg0, arg1, arg2, ... to nominal sons
                my $argno = 0;

                # print STDERR "Sons of ".$n->get_attr('m/form')."\n";
                foreach my $songroup (
                    sort { $a->[0]->get_attr('ord') <=> $b->[0]->get_attr('ord') }

                    # $n->get_children
                    GetEChildren($n)
                    )
                {

                    # print STDERR "  "
                    #   .join(" ", map{$_->get_attr('m/form')}@$songroup)."\n";
                    my $increase_argno = 0;
                    foreach my $son (@$songroup) {
                        my $stag = $son->get_attr('m/tag');
                        if ( $stag =~ /^N/ || $stag =~ /^P/ || $stag eq "DT" ) {
                            $son->set_attr( 'valem',       "arg$argno-of-" . lc($form) );
                            $son->set_attr( 'simplevalem', "arg$argno-of-" . lc($lemma) );
                            $increase_argno = 1;
                        }
                    }
                    $argno++ if $increase_argno;
                }
            }

            # set our valem only in case we don't have one yet
            $n->set_attr( 'valem', $valem )
                if !defined $n->get_attr('valem');
            $simplevalem = $valem if $simplevalem eq "-";
            $n->set_attr( 'simplevalem', $simplevalem )
                if !defined $n->get_attr('simplevalem');
        },
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('m/form'),
                $n->get_attr('m/lemma'),
                $n->get_attr('m/tag'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
                $n->get_attr('valem'),    # valem expresses, how I am formed by
                                          # my parents
                                          # simplevalem is like valem, but we just just the verb lemma
                (   defined $n->get_attr('simplevalem')
                    ? $n->get_attr('simplevalem') : $n->get_attr('valem')
                    )
            ];
        },
    },
    "CzechT" => {
        "sort"    => "deepord",
        "factors" => sub {
            my $n = shift;
            return [
                # obligatory attributes
                $n->get_attr('t_lemma'),
                $n->get_attr('functor'),
                $n->get_attr('deepord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('deepord') : "0" ),

                (
                    # optional attributes, default to '-'
                    map {
                        my $val = $n->get_attr($_);
                        defined $val && $val ne "" ? $val : "-"
                        } (
                        "nodetype",
                        "formeme",
                        "gram/sempos",
                        "gram/number",
                        "gram/negation",
                        "gram/tense",
                        "gram/verbmod",
                        "gram/deontmod",
                        "gram/indeftype",
                        "gram/aspect",
                        "gram/numertype",
                        "gram/degcmp",
                        "gram/dispmod",
                        "gram/gender",
                        "gram/iterativeness",
                        "gram/person",
                        "gram/politeness",
                        "gram/resultative",
                        "is_passive",
                        "is_member",
                        "is_clause_head",
                        "is_relclause_head",
                        "val_frame.rf",
                        )
                ),

                # Something unfinished...
                ## lex.rf's ord
                #eval {
                #    my $a_ord    = 0;
                #    my $a_lex_rf = $n->get_attr('a/lex.rf');
                #    if ( defined $a_lex_rf ) {
                #        my $document = $n->get_document;
                #        my $a_node   = $document->get_node_by_id($a_lex_rf);
                #        $a_ord = $a_node->get_attr("ord");
                #    }
                #    $a_ord;
                #    }
            ];
        },
    },
    "EnglishT" => {
        "sort"    => "deepord",
        "factors" => sub {
            my $n = shift;
            return [
                # obligatory attributes
                $n->get_attr('t_lemma'),
                $n->get_attr('functor'),
                $n->get_attr('deepord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('deepord') : "0" ),

                map {
                    # optional attributes, default to '-'
                    my $val = $n->get_attr($_);
                    defined $val && $val ne "" ? $val : "-"
                    } (
                    "nodetype",
                    "formeme",
                    "gram/sempos",
                    "gram/number",
                    "gram/negation",
                    "gram/tense",
                    "gram/verbmod",
                    "gram/deontmod",
                    "gram/indeftype",
                    "gram/aspect",
                    "gram/numertype",
                    "gram/degcmp",
                    "gram/dispmod",
                    "gram/gender",
                    "gram/iterativeness",
                    "gram/person",
                    "gram/politeness",
                    "gram/resultative",
                    "is_passive",
                    "is_member",
                    "is_clause_head",
                    "is_relclause_head",
                    "val_frame.rf",
                    )
            ];
        },
    },
};

sub process_zone {
    my ( $self, $zone ) = @_;
    my $bundle = $zone->get_bundle();
    my $bundle_id = $zone->get_bundle()->id;

    # if ( $self->join_resegmented && $bundle_id =~ /_(\d+)of(\d+)$/ && $1 != $2 ) {
        # print { $self->_file_handle } $zone->sentence, " ";

#     my $tmt_param_print_factored =
#       $self->get_parameter('TMT_PARAM_PRINT_FACTORED');
#     Report::fatal "Please specify \$TMT_PARAM_PRINT_FACTORED"
#         if !defined $tmt_param_print_factored;
    my @colspecs = split /[\s:]+/, $self->outcols;
    Report::info "Will export: @colspecs";

    # print to stdout or put to an attribute?
    my $tmt_param_destination = $self->to_attribute;

    # my %tmt_param_flags = map { ( $_, 1 ) } split /[\s:]+/,
      # $self->get_parameter('TMT_PARAM_PRINT_FACTORED_FLAGS');

    # my $filename = $document->get_fsfile_name();
    my $filename = "XXXTODO";

    my @output    = ();
    my $output_ok = 1;
    for ( my $i = 0; $i <= $#colspecs; $i++ ) {
        my $colspec = $colspecs[$i];

        if ( $colspec =~ /^([ST])(English|Czech)0$/ ) {

            # specific rules, print just the LANG_SRCTGT_sentence
            my $srctgt = $1;
            my $lang   = lc($2);
            $srctgt = "source" if $srctgt eq "S";
            $srctgt = "target" if $srctgt eq "T";
            my $sent = $bundle->get_attr("${lang}_${srctgt}_sentence");
            Report::fatal
                "Can't print ${lang}_${srctgt}_sentence (for $colspec)"

                if !defined $sent;
            $sent =~ s/[\n\t]+/ /g;
            $sent =~ s/&/&amp;/g;
            $sent =~ s/\|/&pipe;/g;
            push @output, $sent;
            next;
        }

        if ( $colspec =~ /([ST])EnglishCzechAlign([TM])/ ) {

            # TODO: TEnglishCzechAlign is probably not very useful. Should we support it?
            my $srctgt = $1;
            my $layer  = $2;

            if ( $layer eq "M" ) {
                Report::info "AlignM not yet supported";
                push @output, "";
                next;
            }

            # t-layer alignment is contained in SCzechT align/links[$i] {counterpart.rf}
            my $cztree = $bundle->get_tree( $srctgt . "CzechT" );
            Report::fatal "Missing t-layer for $colspec"
                unless defined $cztree;

            # Extracting T-layer alignments
            my @alignments = ();
            foreach my $node ( sort { $a->get_attr('deepord') <=> $b->get_attr('deepord') } $cztree->get_descendants ) {
                my $czord    = $node->get_attr('deepord') - 1;
                my $links_rf = $node->get_attr("align/links");
                next unless defined $links_rf;
                for ( my $i = 0; $i < $links_rf->count; $i++ ) {
                    next unless defined $links_rf->[$i]{"counterpart.rf"};
                    my $enord = $document->get_node_by_id( $links_rf->[$i]{"counterpart.rf"} )->get_attr("deepord") - 1;
                    push @alignments, "$enord-$czord";
                }
            }
            push @output, join( " ", @alignments );
            next;

            # TODO: maybe we should sort alignments by deepords ?
        }

        if ( $colspec =~ /([ST])(English|Czech)(Lex|Aux)RF$/ ) {

            # printing lex.rf mapping for (SRC|TGT)LANG A and T correspondence
            my $srctgt = $1;
            my $lang   = $2;
            my $lexaux = lc($3);

            my $troot = $bundle->get_tree( $srctgt . $lang . "T" );
            Report::fatal "Missing t-layer for $colspec"
                if !defined $troot;

            my $aroot = $bundle->get_tree( $srctgt . $lang . "A" );
            Report::fatal "Missing a-layer for $colspec"
                if !defined $aroot;

            my $tsortattr     = $export_rules->{ $lang . "T" }->{"sort"};
            my @tsorted_nodes = $troot->get_descendants;
            if ( defined $tsortattr ) {
                @tsorted_nodes =
                    sort { $a->get_attr($tsortattr) <=> $b->get_attr($tsortattr) }
                    @tsorted_nodes;
            }

            my $asortattr     = $export_rules->{ $lang . "A" }->{"sort"};
            my @asorted_nodes = $aroot->get_descendants;
            if ( defined $asortattr ) {
                @asorted_nodes =
                    sort { $a->get_attr($asortattr) <=> $b->get_attr($asortattr) }
                    @asorted_nodes;
            }
            my %aid_to_aord = map {
                my $aid = $asorted_nodes[$_]->get_attr("id");

                # print STDERR "aord: $_; aid: $aid\n";
                ( $aid, $_ );
            } ( 0 .. $#asorted_nodes );

            my @reflinks = map {
                my $tord  = $_;
                my $tnode = $tsorted_nodes[$tord];
                my $links = $tnode->get_attr("a/$lexaux.rf");
                if ( ref($links) eq "" ) {
                    if ( !defined $links || $links eq "" ) {

                        # print "NONE $lexaux\n";
                        $links = [];
                    }
                    else {

                        # print "SINGLE $lexaux: $links\n";
                        $links = [$links];
                    }
                }
                elsif ( reftype($links) eq "ARRAY" ) {
                    $links = [ $links->values() ];

                    # print "LIST $lexaux: ".join(" ", @$links)."\n";
                }
                else {
                    Report::fatal "Unexpected links type: " . ref($links)
                }

                if ( 0 == scalar @$links ) {
                    ();
                }
                else {
                    my @newlinks = map {
                        "$aid_to_aord{$_}-$tord";
                       }
                       grep {
                        if (!defined $aid_to_aord{$_}) {
                           if ($allow_links_to_different_sentences) {
                               0;
                           } else {
                               Report::fatal
                                 "Undefined a-node ID $_ in $lexaux.rf for "
                                    . $tnode->get_attr("id");
                           }
                        } else {
                            1;  # keep this node
                         }
                       } @$links;
                    # for this node, return the (shortened) list of links:
                    (@newlinks);
                }
            } ( 0 .. $#tsorted_nodes );

            push @output, join( " ", @reflinks );
            next;
        }

        my $tmp = $colspec;
        my $exportspec = substr( $tmp, 1 );

        Report::fatal "Export rules not defined for $colspec"
            if !defined $export_rules->{$exportspec};

        my $sortattr          = $export_rules->{$exportspec}->{"sort"};
        my $factors_generator = $export_rules->{$exportspec}->{"factors"};

        my $treename = $colspec;
        $treename = substr($colspec, 0, 1)
          .$export_rules->{$exportspec}->{"treename"}
          if defined $export_rules->{$exportspec}->{"treename"};
        my $root = $bundle->get_tree($treename);

        my $top_down_modifier = $export_rules->{$exportspec}
            ->{"top_down_modifier"};
        if ( defined $top_down_modifier ) {
            my @q = ($root);
            while ( my $n = shift @q ) {
                $top_down_modifier->($n);
                push @q, ( $n->get_children );
            }
        }

        # allow the export rules to set their data
        my $preprocessor = $export_rules->{$exportspec} ->{"preprocessor"};
        my $preprocdata = $preprocessor->($root)
          if defined $preprocessor;

        my @sorted_nodes = $root->get_descendants;
        if ( defined $sortattr ) {
            @sorted_nodes =
                sort { $a->get_attr($sortattr) <=> $b->get_attr($sortattr) }
                @sorted_nodes;
        }

        my @outtokens = ();
        foreach my $n (@sorted_nodes) {
            my $outfactors = $factors_generator->($n, $preprocdata);
            my $outtoken   = join(
                "|",
                map {
                    Report::fatal
                      $bundle->get_attr("id").":"
                      ."Bad factor value '$_' in $colspec, "
                        ."contains space in: @$outfactors"
                        if $_ =~ /\s/;
                    $_
                }
                map {
                    if ($tmt_param_flags{"join_spaced_numbers"}) {
                      # disregard a single space between two digits in
                      # attribute values (form, a-lemma, t-lemma if created
                      # by SCzechW_to_SCzechM::Tokenize_joining_numbers
                      s/([0-9]) ([0-9])/$1$2/g;
                      s/([0-9][,.]) ([0-9])/$1$2/g;
                      s/([0-9]) ([,.][0-9])/$1$2/g;
                    }
                    if ($tmt_param_flags{"escape_space"}) {
                      # escape space with '&space;'
                      s/ /&space;/g;
                    }
                    $_
                }
                map { s/&/&amp;/g; s/\|/&pipe;/g; $_ }
                map {
                  Report::fatal
                    $bundle->get_attr("id").":"
                    ."Failed to export $colspec, missing or blank value in: "
                      ."@$outfactors"
                      if !defined $_ || $_ eq "";
                    $_
                }
                @$outfactors
            );
            push @outtokens, $outtoken;
        }

        # Soon to be removed, we should just emit a blank column
        #if (0 == scalar @sorted_nodes) {
        #    print STDERR "Skipping sentence ".($bundle->get_attr("id"))
        #        .", blank $colspec\n";
        #    $output_ok = 0;
        #}

        push @output, join( " ", @outtokens );
    }
    if ($output_ok) {
        my $outstr = join( "\t", @output );
        if (! defined $tmt_param_destination ) {
          print $filename . ":" . $bundle->get_attr("id"). "\t"
            . $outstr . "\n";
        } else {
          $bundle->set_attr($tmt_param_destination, $outstr)
        }
    }
    
}

1;

__END__

=head1 NAME

Treex::Block::Write::Factored

=head1 DESCRIPTION

Document writer for plain text format.
The text is taken from the document's attribute C<text>,
if you want to save the sentences stored in L<bundles|Treex::Core::Bundle>,
use L<Treex::Block::Write::Sentences>.

Document writer for 'factored' or 'export' format.
For every sentence produces one line of information.
The line consist of
filename:sentid column followed by columns according to your specification in


=head1 ATTRIBUTES

=over

=item outcols

a sequence of keywords, each keyword introduces an
output column.

The following keywords (i.e. output columns) are supported:

  [TS](Czech|English)[TA]
    ... print factored version of every t- or a- node in sentord or ord.
  [TS](Czech|English)M
    ... useful for files that have no a-layer
  [TS](Czech|English)0
    ... useful for files with zero annotation (just LANG_source_sentence)
  [TS](Czech|English)(Lex|Aux)RF
    ... print 'alignment-like' notation for a-to-t lex.rf or aux.rf links.
        Nodes are refered to using their linear (sentord/ord) order starting
        from 0.
  [TS]EnglishCzechAlign[TM]
    ... print alignments between corresponding t- or m- layers. Nodes are
        refered to using deepord for t- layer and linear (sentord/ord) for m-
        layer starting from 0 (thus node with actual deepord 5 is refered to by
        4).

=item to

space or comma separated list of filenames, or C<-> for STDOUT 

=item to_attribute

name of the block attribute that should be filled by the string instead of
printing the string to stdout/file.


=back

=head1 METHODS

=over

=item process_document

Processes all bundles in the document.

=back

=head1 AUTHOR

Ondrej Bojar

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

