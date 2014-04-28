package Treex::Block::Write::Factored;
use Moose;
use File::Spec;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Write::ToBundleAttr';

has to_attribute => ( isa => 'Str', is => 'ro' );

has flags => ( isa => 'Str', is => 'ro' );

has outcols => (
    is            => 'ro',
    isa           => 'Str',
    default       => 'relpath_with_id:RFaux-cs',
    documentation => 'The columns to emit.',
);

has default_value => (
    is            => 'ro',
    isa           => 'Str',
    documentation => 'The default value for empty factors.',
);

has '+extension' => ( default => '.tsv' );

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
    my $node   = shift;
    my $root   = $node->get_root();
    my $bundle = $node->get_bundle();
    my ($tree_name) = grep { $bundle->get_tree($_) == $root } $bundle->get_tree_names();
    return $tree_name;
}

sub preprocessor_for_at_output {

    # construct aidtotid map
    my $aroot     = shift;
    my $aidtotid  = undef;
    my $bundle    = $aroot->get_bundle();
    my $zone      = $aroot->_get_zone();
    my $troot     = $bundle->get_tree($zone->language, "t", $zone->selector);
    log_fatal "Failed to get t_tree for " . $aroot->id
        if !defined $troot;
    foreach my $tnode ( $troot->get_descendants ) {
        my $links = $tnode->get_attr("a/lex.rf");
        if ( ref($links) eq "" ) {
            if ( !defined $links || $links eq "" ) {
                $links = [];
            }
            else {
                $links = [$links];
            }
        }
        elsif ( reftype($links) eq "ARRAY" ) {
            $links = [ $links->values() ];
        }
        else {
            log_fatal "Unexpected links type: " . ref($links)
        }
        log_fatal "More than one lex.rf at "
            . $tnode->get_attr('id')
            if 1 < scalar @$links;
        if ( 1 == scalar @$links ) {
            my $aid = $links->[0];
            my $tid = $tnode->id;
            log_fatal "Two t-nodes point to the same a-node $aid: "
                . "$tid vs. $aidtotid->{$aid}"
                if defined $aidtotid->{$aid};
            $aidtotid->{$aid} = $tid;
        }
    }
    return $aidtotid;
}

sub producer_of_at_output {
    my $n        = shift;
    my $aidtotid = shift;
    my $aid      = $n->get_attr('id');
    my $tid      = $aidtotid->{$aid};
    my $tnode    = undef;
    if ( defined $tid ) {
        my $doc = $n->get_document();
        $tnode = $doc->get_node_by_id($tid);
    }
    return [
        $n->get_attr('form'),
        $n->get_attr('lemma'),
        $n->get_attr('tag'),
        $n->get_attr('ord'),
        ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
        $n->get_attr('afun'),
        (    # a sequence of t-layer attributes
            map {
                my $o = $tnode->get_attr($_) if defined $tnode;
                $o = "-" if !defined $o;
                $o;
                }
                (
                "t_lemma", "functor", "nodetype",
                "formeme", "gram/sempos",
                )
            )
    ];
}

my $export_rules = {
    "enw" => {    # Czech w-layer
        "uselayer" => "a",
        "sort"    => "ord",
        "factors"  => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
            ];
        },
    },
    "csw" => {    # Czech w-layer
        "uselayer" => "a",
        "sort"    => "ord",
        "factors"  => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
            ];
        },
    },
    "csm" => {    # Czech m-layer
        "uselayer" => "a",
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
            ];
        },
    },
    "csa" => {    # Czech a-layer, more or less canonic
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
                $n->get_attr('afun'),
            ];
        },
    },
    "csA" => {    # Czech a-layer with additional attributes from t-layer (via lex.rf)
        "uselayer"     => "a",
        "sort"         => "ord",
        "preprocessor" => sub {&preprocessor_for_at_output},
        "factors"      => sub {&producer_of_at_output},
    },
    "him" => {
        "uselayer" => "a",
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
            ];
        },
    },
    "enm" => {
        "uselayer" => "a",
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
            ];
        },
    },
    "ena" => {
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
                $n->get_attr('afun'),
            ];
        },
    },
    "enA" => {    # English a-layer with additional attributes from t-layer (via lex.rf)
        "uselayer"     => "a",
        "sort"         => "ord",
        "preprocessor" => sub {&preprocessor_for_at_output},
        "factors"      => sub {&producer_of_at_output},
    },
    "UNUSED EnglishAvalem" => {
        "sort"              => "ord",
        "top_down_modifier" => sub {
            my $n = shift;
            my $p = $n->get_parent;
            return if !defined $p;    # don't set anything for the root

            ## set valem, a factor describing the relation of a dependent
            ## towards the head
            my $valem       = "-";
            my $simplevalem = "-";
            my $lemma       = $n->get_attr('lemma');
            my $form        = $n->get_attr('form');
            my $tag         = $n->get_attr('tag');
            die "undefined $lemma, $form, $tag, id:" . $n->get_attr('id') if !defined $tag;
            if ( defined $p ) {
                my $plemma       = $p->get_attr('lemma')     || "-";       # for the root
                my $ptag         = $p->get_attr('tag')       || "-";
                my $pvalem       = $p->get_attr('lem')       || "-";
                my $psimplevalem = $p->get_attr('simplevalem') || $pvalem;
                $valem = $plemma if $ptag =~ /^(IN|TO|RB)$/;
                $valem = $lemma  if $tag  =~ /^(IN|TO|RB)$/;

                # prepositions set valem
                if (
                    (   $tag    eq "DT"
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

                # print STDERR "Sons of ".$n->get_attr('form')."\n";
                foreach my $songroup (
                    sort { $a->[0]->get_attr('ord') <=> $b->[0]->get_attr('ord') }

                    # $n->get_children
                    GetEChildren($n)
                    )
                {

                    # print STDERR "  "
                    #   .join(" ", map{$_->get_attr('form')}@$songroup)."\n";
                    my $increase_argno = 0;
                    foreach my $son (@$songroup) {
                        my $stag = $son->get_attr('tag');
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
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
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
    "jaa" => {    # Japanese a-layer, more or less canonic
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [
                $n->get_attr('form'),
                $n->get_attr('lemma'),
                $n->get_attr('tag'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),
                $n->get_attr('afun'),
            ];
        },
    },
    "cst" => {
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [

                # obligatory attributes
                $n->get_attr('t_lemma'),
                $n->get_attr('functor'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),

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
    "ent" => {
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [

                # obligatory attributes
                $n->get_attr('t_lemma'),
                $n->get_attr('functor'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),

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
    "jat" => {  # Japanese t-layer
        "sort"    => "ord",
        "factors" => sub {
            my $n = shift;
            return [

                # obligatory attributes
                $n->get_attr('t_lemma'),
                $n->get_attr('functor'),
                $n->get_attr('ord'),
                ( defined $n->get_parent ? $n->get_parent->get_attr('ord') : "0" ),

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
};

sub BUILD {
    my ($self) = @_;

    #     my $tmt_param_print_factored =
    #       $self->get_parameter('TMT_PARAM_PRINT_FACTORED');
    #     log_fatal "Please specify \$TMT_PARAM_PRINT_FACTORED"
    #         if !defined $tmt_param_print_factored;
    my @colspecs = split /[\s:]+/, $self->outcols;
    log_info "Write::Factored will export: @colspecs";

    my %tmt_param_flags = map { ( $_, 1 ) } split /[\s:]+/, $self->flags
        if defined $self->flags;

    $self->{tmt_param_flags} = \%tmt_param_flags;
    $self->{colspecs} = \@colspecs;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $bundle_id = $bundle->id;

    # print to stdout or put to an attribute?
    my $tmt_param_destination = $self->to_attribute;

    my $pathname_cached = undef;
    my @output    = ();
    my $output_ok = 1;
    for ( my $i = 0; $i < scalar(@{$self->{colspecs}}); $i++ ) {
        my $colspec = $self->{colspecs}->[$i];

        if ( $colspec =~ /^ATTR(.*)$/) {
            push @output, $bundle->attr($1);
            next;
        }

        if ( $colspec =~ /^(abs|rel)path(_with_id)?$/) {
            if (!defined $pathname_cached) {
                my $absrel = $1;
                my $maybundleid = $2;
                $pathname_cached = $bundle->get_document->_pmldoc->filename();
                $pathname_cached = File::Spec->abs2rel($pathname_cached)
                    if $absrel eq "rel";
                $pathname_cached .= ":".$bundle->id()
                    if $maybundleid;
            }
            push @output, $pathname_cached;
            next;
            # TODO: maybe we should sort alignments by ord ?
        }

        if ( $colspec =~ /^(rev)?ALI([ta])-(..)([^-]*?)-(..)([^-]*?)(-.*)?/ ) {
            my $mayrev  = $1;
            my $layer  = $2;
            my $lang1 = $3;
            my $sel1 = $4;
            my $lang2 = $5;
            my $sel3 = $6;
            my $require_type = $7;
            $require_type =~ s/^-// if defined $require_type;
            $require_type = undef
              if defined $require_type && $require_type eq "";
            # a flag to reverse the alignment before printing
            my $rev = 0;
            $rev = 1 if defined $mayrev && $mayrev eq "rev";

            # t-layer alignment is contained in SCzechT align/links[$i] {counterpart.rf}
            my $tree1 = $bundle->get_tree($lang1, $layer, $sel1);
            log_fatal "Missing t-layer for $lang1 (selector '$sel1')"
                if ! defined $tree1;

            my $document = $tree1->get_document();

            # Extracting T-layer alignments
            my @alignments = ();
            foreach my $node1 ( sort { $a->get_attr('ord') <=> $b->get_attr('ord') } $tree1->get_descendants ) {
                my $ord1    = $node1->get_attr('ord') - 1;
                my ($nodes2, $types) = $node1->get_aligned_nodes();
                next if ! defined $nodes2;
                for(my $i=0; $i<scalar(@$nodes2); $i++) {
#                 foreach my $node2 (keys %$counterparts_and_type) {
#                   my $type = $counterparts_and_type->{$node2};
                  my $type = $types->[$i];
                  my $node2 = $nodes2->[$i];
                  my $ord2 = $node2->get_attr("ord") - 1;
                  my $outpair = ($rev ? "$ord2-$ord1" : "$ord1-$ord2" );
                  if (defined $require_type) {
                    push @alignments, $outpair
                      if $type =~ /\b$require_type\b/;
                  } else {
                    push @alignments, "$type:$outpair";
                  }
                }
            }
            push @output, join( " ", sort {$a cmp $b} @alignments );
            next;
        }

        if ( $colspec =~ /RF(lex|aux)-(..)(.*)$/ ) {
            # printing lex.rf or aux.rf mapping for LANG A and T correspondence
            my $lexaux = $1;
            my $lang   = $2;
            my $selector = $3;

            my $troot = $bundle->get_tree($lang, "t", $selector);
            log_fatal "Missing t-layer for $colspec"
                if !defined $troot;

            my $aroot = $bundle->get_tree($lang, "a", $selector);
            log_fatal "Missing a-layer for $colspec"
                if !defined $aroot;

            my $tsortattr     = $export_rules->{ $lang . "t" }->{"sort"};
            my @tsorted_nodes = $troot->get_descendants;
            if ( defined $tsortattr ) {
                @tsorted_nodes =
                    sort { $a->get_attr($tsortattr) <=> $b->get_attr($tsortattr) }
                    @tsorted_nodes;
            }

            my $asortattr     = $export_rules->{ $lang . "a" }->{"sort"};
            my @asorted_nodes = $aroot->get_descendants;
            if ( defined $asortattr ) {
                @asorted_nodes =
                    sort { $a->get_attr($asortattr) <=> $b->get_attr($asortattr) }
                    @asorted_nodes;
            }
            my %aid_to_aord = map {
                my $aid = $asorted_nodes[$_]->id;

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
                    log_fatal "Unexpected links type: " . ref($links)
                }

                if ( 0 == scalar @$links ) {
                    ();
                }
                else {
                    my @newlinks = map {
                        "$aid_to_aord{$_}-$tord";
                        }
                        grep {
                        if ( !defined $aid_to_aord{$_} ) {
                            if ($allow_links_to_different_sentences) {
                                0;
                            }
                            else {
                                log_fatal
                                    "Undefined a-node ID $_ in $lexaux.rf for "
                                    . $tnode->id;
                            }
                        }
                        else {
                            1;    # keep this node
                        }
                        } @$links;

                    # for this node, return the (shortened) list of links:
                    (@newlinks);
                }
            } ( 0 .. $#tsorted_nodes );

            push @output, join( " ", @reflinks );
            next;
        }

        if ( $colspec =~ /^(..)0(.*)$/ ) {
            # specific rules, print just the LANG_SRCTGT_sentence
            my $lang   = $1;
            my $selector = $2;
            my $zone = $bundle->get_zone($lang, $selector);
            log_fatal "Zone $lang ($selector) not found for $colspec"
                if ! defined $zone;
            my $sent = $zone->sentence;
            log_fatal "Can't print attribute sentence"
                ." for $lang ($selector) for $colspec"
                if !defined $sent;
            $sent =~ s/[\n\t]+/ /g;
            $sent =~ s/&/&amp;/g;
            $sent =~ s/\|/&pipe;/g;
            push @output, $sent;
            next;
        }

        if ( $colspec =~ /^(..)([wmatA])(.*)$/ ) {
            my $lang   = $1;
            my $layer   = $2;
            my $selector = $3;
            my $exportspec = $lang.$layer;
    
            log_fatal "Export rules not defined for $exportspec for $colspec"
                if !defined $export_rules->{$exportspec};
    
            my $sortattr          = $export_rules->{$exportspec}->{"sort"};
            my $factors_generator = $export_rules->{$exportspec}->{"factors"};
    
            my $uselayer = defined $export_rules->{$exportspec}->{"uselayer"}
                ? $export_rules->{$exportspec}->{"uselayer"} : $layer;
            my $root = $bundle->get_tree($lang, $uselayer, $selector);
    
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
            my $preprocessor = $export_rules->{$exportspec}->{"preprocessor"};
            my $preprocdata  = $preprocessor->($root)
                if defined $preprocessor;
    
            my @sorted_nodes = $root->get_descendants;
            if ( defined $sortattr ) {
                @sorted_nodes =
                    sort { $a->get_attr($sortattr) <=> $b->get_attr($sortattr) }
                    @sorted_nodes;
            }
    
            my @outtokens = ();
            foreach my $n (@sorted_nodes) {
                my $outfactors = $factors_generator->( $n, $preprocdata );
                my $outtoken = join(
                    "|",
                    map {
                        log_fatal
                            $bundle->id() . ":"
                            . "Bad factor value '$_' in $colspec, "
                            . "contains space in: @$outfactors"
                            . "; Use flags=escape_space"
                            if $_ =~ /\s/;
                        $_
                        }
                        map {
                        if ( $self->{tmt_param_flags}->{"join_spaced_numbers"} ) {
    
                            # disregard a single space between two digits in
                            # attribute values (form, a-lemma, t-lemma if created
                            # by SCzechW_to_SCzechM::Tokenize_joining_numbers
                            s/([0-9]) ([0-9])/$1$2/g;
                            s/([0-9][,.]) ([0-9])/$1$2/g;
                            s/([0-9]) ([,.][0-9])/$1$2/g;
                        }
                        if ( $self->{tmt_param_flags}->{"escape_space"} ) {
    
                            # escape space with '&space;'
                            s/ /&space;/g;
                        }
                        $_
                        }
                        map { s/&/&amp;/g; s/\|/&pipe;/g; $_ }
                        map {
                        log_fatal
                            $bundle->id() . ":"
                            . "Failed to export $colspec, missing or blank value in: "
                            . "@$outfactors"
                            if !defined $_ || $_ eq "";
                        $_
                        }
                        map {
                        if ( ( !defined $_ || $_ eq "" )
                             && defined $self->{default_value} ) {
                          $_ = $self->{default_value};
                        }
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
            next;
        }

        log_fatal "Unrecognized colspec: $colspec";
    }
    if ($output_ok) {
        my $outstr = join( "\t", @output );
        if ( !defined $tmt_param_destination ) {
            print { $self->_file_handle } # to be redirectable
                $outstr, "\n";
        }
        else {
            $bundle->set_attr( $tmt_param_destination, $outstr )
        }
    }

}

1;

__END__

=head1 NAME

Treex::Block::Write::Factored

=head1 DESCRIPTION

Document writer for 'factored' or 'export' format.
For every sentence produces one line of information: tab-delimited columns
according to the attribute outcols.

Sample usage:

  Write::Factored
    outcols=relpath_with_id:ena:ent:RFlex-en:RFaux-en
    flags=join_spaced_numbers:escape_space

=head1 ATTRIBUTES

=over

=item outcols

a sequence of keywords, each keyword introduces an
output column.

The following keywords (i.e. output columns) are supported:

  (rel|abs)path(_with_id)
    ... the pathname of the document, followed by colon and bundle ID

  ATTR<bundle-attribute-name>
    ... verbatim copy of the given bundle attribute name

  (rev)?ALI[tm]-<Language1>-<Language2>(-RequiredTypes)?
    ... print alignments between corresponding t- or m- layers. Nodes are
        refered to using ord values minus 1 (thus node with actual deepord 5 is
        refered to by 4).
  RF(lex|aux)-<Language><Selector>
    ... print 'alignment-like' notation for a-to-t lex.rf or aux.rf links.
        Nodes are refered to using their linear (sentord/ord) order starting
        from 0.
    
  <Language><Layer><Selector>
    Layer is one of:
      w       = w-layer, just tokens
      m, a, t = m-, a- and t-layer
                ... print factored version of every t- or a- node in sentord or
                    ord.
      A       = like a-layer but with extra factors from t-layer
      0       = just the <sentence> attribute from the zone


=item to

space or comma separated list of filenames, or C<-> for STDOUT 

=item to_attribute

name of the block attribute that should be filled by the string instead of
printing the string to stdout/file.


=back

=head1 METHODS

=over

=item process_bundle

Prints one line of output based on the specification in 'outcols'.

=back

=head1 AUTHOR

Ondrej Bojar

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

