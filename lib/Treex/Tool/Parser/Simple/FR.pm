package Treex::Tool::Parser::Simple::FR;
use utf8;
use Moose;
use Treex::Core::Common;
with 'Treex::Tool::Parser::Role';

sub parse_sentence {
    my ( $self, $wordforms_rf, $lemmas_rf, $tags_rf ) = @_;
    my @parents;

    my @sentence;

    for ( my $i = 0; $i < @{$wordforms_rf}; $i++ ) {
        $sentence[$i]{form}   = $wordforms_rf->[$i];
        $sentence[$i]{tag}    = $tags_rf->[$i];
        $sentence[$i]{parent} = -1;
    }
    @parents = my_parse_sentence( \@sentence );

    return (\@parents, undef);
}

# brief                     Searches for the next word with specified POS from specified position in the sentence
# param ref $sentence_ref   Reference to the sentence
# param string $pos_tag     The part of speech tag we are looking for
# param int $start_index    The position in the sentence where we start the search
# returns int               Position of the found word (if it's equal to $start_index, we found nothing)
#
# Usage: we want to find next adverb after the verb on position 3 in the sentence:
# my $next_adv = find_next_from($sentence_ref, "adv", 3);
sub find_next_from {
    my ( $sentence_ref, $pos_tag, $start_index ) = @_;
    for ( my $i = $start_index + 1; $i < @{$sentence_ref}; $i++ ) {

        #       print "$i " . $sentence_ref->[$i]{"tag"} . "\n";
        if ( $sentence_ref->[$i]{"tag"} eq $pos_tag ) {
            return $i;
        }
    }

    #   print "$start_index \n";
    return $start_index;
}

# brief                     Searches for the previous word with specified POS from specified position in the sentence
# param ref $sentence_ref   Reference to the sentence
# param string $pos_tag     The part of speech tag we are looking for
# param int $start_index    The position in the sentence where we start the search
# returns int               Position of the found word (if it's equal to $start_index, we found nothing)
#
# Usage: we want to find next adjective before the noun on position 3 in the sentence:
# my $prev_adj = find_prev_from($sentence_ref, "adj", 3);
sub find_prev_from {
    my ( $sentence_ref, $pos_tag, $start_index ) = @_;
    for ( my $i = $start_index - 1; $i >= 0; $i-- ) {

        #       print "$i " . $sentence_ref->[$i]{"tag"} . "\n";
        if ( $sentence_ref->[$i]{"tag"} eq $pos_tag ) {
            return $i;
        }
    }

    #   print "$start_index \n";
    return $start_index;
}

# Function tries to parse the sentence using trivial rules like:
# article depends on the next noun
# numeral depends on the next noun
# noun + noun are a noun phrase
#
# note that this parsing is not so great because it heavily depends on the tagger and
# the rules are very simple and sometimes wrong...
# but I don't know french :( so it's not very easy to create better rules...
sub my_parse_sentence {
    my ($sentence_ref) = @_;

    my $last_index = @{$sentence_ref} - 1;
    $sentence_ref->[$last_index]{"parent"} = 0;
    my $pred_index = $last_index;

    for ( my $i = 0; $i < @{$sentence_ref} - 1; $i++ ) {
        my $current_tag = $sentence_ref->[$i]{"tag"};
        my $next_tag    = $sentence_ref->[ $i + 1 ]{"tag"};

        my $current_form = $sentence_ref->[$i]{"form"};

        #       $next_form = $sentence_ref->[$i + 1]{"form"};

        # art -> noun
        if ( $current_tag eq "art" ) {
            my $next_noun = find_next_from( $sentence_ref, "noun", $i );

            #           print "article at $i -- next noun: $next_noun\n";
            if ( $next_noun != $i ) {
                $sentence_ref->[$i]{"parent"} = $next_noun;
            }
        }

        # num -> noun
        if ( $current_tag eq "num" ) {
            my $next_noun = find_next_from( $sentence_ref, "noun", $i );
            if ( $next_noun != $i ) {
                $sentence_ref->[$i]{"parent"} = $next_noun;
            }
        }

        # noun phrase
        if ( $current_tag eq "noun" && $next_tag eq "noun" ) {
            $sentence_ref->[$i]{"parent"} = $i + 1;
        }

        # noun - adj pattern, prefer adj after noun
        if ( $current_tag eq "adj" ) {
            my $next_noun = find_next_from( $sentence_ref, "noun", $i );
            my $next_pron = find_next_from( $sentence_ref, "pron", $i );
            my $prev_noun = find_prev_from( $sentence_ref, "noun", $i );
            my $prev_pron = find_prev_from( $sentence_ref, "pron", $i );
            if ( $next_noun > $next_pron && $next_pron != $i ) {
                $next_noun = $next_pron;
            }
            if ( $prev_noun > $prev_pron && $prev_pron != $i ) {
                $prev_noun = $prev_pron;
            }

            #           print "for $i adj: next noun: $next_noun prev noun: $prev_noun\n";
            if ( ( $next_noun - $i ) < ( $i - $prev_noun ) ) {
                if ( $next_noun != $i ) {
                    $sentence_ref->[$i]{"parent"} = $next_noun;

                    #                   print ("chosen $next_noun\n");
                }
                elsif ( $prev_noun != $i ) {
                    $sentence_ref->[$i]{"parent"} = $prev_noun;

                    #                       print ("chosen $prev_noun\n");
                }
            }
            else {

                # prev noun is favourite
                if ( $prev_noun != $i ) {
                    $sentence_ref->[$i]{"parent"} = $prev_noun;

                    #                   print ("chosen $prev_noun\n");
                }
                elsif ( $next_noun != $i ) {
                    $sentence_ref->[$i]{"parent"} = $next_noun;

                    #                   print ("chosen $next_noun\n");
                }
            }
        }

        # negative adverbs, such as pas ("not"), plus ("not any more"), and jamais come before the infinitive
        if ( $current_form eq "pas" || $current_form eq "plus" || $current_form eq "jamais" || $current_form eq "ne" ) {
            my $next_verb = find_next_from( $sentence_ref, "verb", $i );
            if ( $next_verb != $i ) {
                $sentence_ref->[$i]{"parent"} = $next_verb;
            }
        }

        # adverb that modifies an infinitive (verbal noun) generally comes after the infinitive
        # adverb that modifies a main verb or clause comes either after the verb, or before the clause
        if ( $current_tag eq "adv" && $sentence_ref->[$i]{"parent"} == -1 ) {
            my $first_verb_before = find_prev_from( $sentence_ref, "verb", $i );
            if ( $first_verb_before != $i ) {
                $sentence_ref->[$i]{"parent"} = $first_verb_before;

                # print "adv -> $first_verb_before\n";
            }
        }

        # adverb that modifies an adjective or adverb comes before that adjective or adverb
        if ( $current_tag eq "adv" && $sentence_ref->[$i]{"parent"} == -1 ) {
            my $first_verb_before = find_prev_from( $sentence_ref, "verb", $i );
            my $first_verb_after = find_next_from( $sentence_ref, "verb", $i );
            my $next_adv         = find_next_from( $sentence_ref, "adv",  $i );
            my $next_adj         = find_next_from( $sentence_ref, "adj",  $i );
            my $min_pos          = $i;

            # first, find closest adverb or adjective
            if ( ( $next_adv - $i ) < ( $next_adj - $i ) ) {
                if ( $next_adv != $i ) {
                    $min_pos = $next_adv;
                }
                elsif ( $next_adj != $i ) {
                    $min_pos = $next_adj;
                }
            }
            else {
                if ( $next_adj != $i ) {
                    $min_pos = $next_adj;
                }
                elsif ( $next_adv != $i ) {
                    $min_pos = $next_adv;
                }
            }

            if ( $min_pos == $i ) {

                # if we found no adverb, neither adj, use next verb...
                $min_pos = $first_verb_before;
            }
            else {
                if ( ( $i - $first_verb_before ) < ( $min_pos - $i ) ) {
                    if ( $i != $first_verb_before ) {
                        $min_pos = $first_verb_before;
                    }
                }
            }

            # fallback -- najdi nasledujuce sloveso, lebo neexistuje za adv ani ine adv, ani adj, ani pred nim sloveso
            if ( $min_pos == $i ) {
                $min_pos = $first_verb_after;
            }

            # absolute fallback
            if ( $min_pos == $i ) {
                $min_pos = $i - 1;
            }

            $sentence_ref->[$i]{"parent"} = $min_pos;
        }

        # prep -> noun
        if ( $current_tag eq "prep" ) {

            # ak existuje subst za predlozkou, tak ho zaves pod tu predlozku
            my $next_noun = find_next_from( $sentence_ref, "noun", $i );
            if ( $next_noun != $i ) {
                $sentence_ref->[$next_noun]{"parent"} = $i;
            }

            # predlozku zaves pod najblizsie sloveso
            my $next_verb = find_next_from( $sentence_ref, "verb", $i );
            if ( $next_verb != $i ) {
                $sentence_ref->[$i]{"parent"} = $next_verb;
            }
        }

        # noun -> closest verb
        if ( $current_tag eq "noun" && $sentence_ref->[$i]{"parent"} == -1 ) {
            my $next_verb_pos = find_next_from( $sentence_ref, "verb", $i );
            my $prev_verb_pos = find_prev_from( $sentence_ref, "verb", $i );

            if ( ( $next_verb_pos - $i ) < ( $i - $prev_verb_pos ) ) {
                if ( $next_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $next_verb_pos;
                }
                elsif ( $prev_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $prev_verb_pos;
                }
            }
            else {

                # prev verb is closer
                if ( $prev_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $prev_verb_pos;
                }
                elsif ( $next_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $next_verb_pos;
                }
            }
        }

        # pronoun -> closest verb
        if ( $current_tag eq "pron" ) {
            my $next_verb_pos = find_next_from( $sentence_ref, "verb", $i );
            my $prev_verb_pos = find_prev_from( $sentence_ref, "verb", $i );

            if ( ( $next_verb_pos - $i ) < ( $i - $prev_verb_pos ) ) {
                if ( $next_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $next_verb_pos;
                }
                elsif ( $prev_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $prev_verb_pos;
                }
            }
            else {

                # prev verb is closer
                if ( $prev_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $prev_verb_pos;
                }
                elsif ( $next_verb_pos != $i ) {
                    $sentence_ref->[$i]{"parent"} = $next_verb_pos;
                }
            }
        }

        # if not pronoun -> closest verb, then on next noun
        if ( $current_tag eq "pron" && $sentence_ref->[$i]{"parent"} == -1 ) {
            my $next_noun = find_next_from( $sentence_ref, "noun", $i );
            if ( $next_noun != $i ) {
                $sentence_ref->[$i]{"parent"} = $next_noun;
            }

        }

        # conj -- search for the closest noun or verb pair and let them be dependent on the conj
        #       if ($current_tag eq "conj"){
        #           my $next_verb_pos = find_next_from($sentence_ref, "verb", $i);
        #           my $prev_verb_pos = find_prev_from($sentence_ref, "verb", $i);
        #
        #           my $next_noun_pos = find_next_from($sentence_ref, "noun", $i);
        #           my $prev_noun_pos = find_prev_from($sentence_ref, "noun", $i);
        #
        #           if(($next_verb_pos - $prev_verb_pos) < ($next_noun_pos - $prev_noun_pos)) {
        #               if($next_verb_pos != $i && $prev_verb_pos != $i) {
        #                   $sentence_ref->[$next_verb_pos]{"parent"} = $i;
        #                   $sentence_ref->[$prev_verb_pos]{"parent"} = $i;
        #               } elsif($next_noun_pos != $i && $prev_noun_pos != $i) {
        #                   $sentence_ref->[$next_noun_pos]{"parent"} = $i;
        #                   $sentence_ref->[$prev_noun_pos]{"parent"} = $i;
        #               }
        #           } else {
        #               if($next_noun_pos != $i && $prev_noun_pos != $i) {
        #                   $sentence_ref->[$next_noun_pos]{"parent"} = $i;
        #                   $sentence_ref->[$prev_noun_pos]{"parent"} = $i;
        #               } elsif($next_verb_pos != $i && $prev_verb_pos != $i) {
        #                   $sentence_ref->[$next_verb_pos]{"parent"} = $i;
        #                   $sentence_ref->[$prev_verb_pos]{"parent"} = $i;
        #               }
        #           }
        #       }
        #
        #other interp
        if ( $current_tag eq "interp" && $sentence_ref->[$i]{"parent"} == -1 ) {
            $sentence_ref->[$i]{"parent"} = $i - 1 > 0 ? $i - 1 : $i + 1;
        }

        # last verb as a predicate (too lousy :/)
        my $last_verb = find_prev_from( $sentence_ref, "verb", $last_index );
        my $last_noun = find_prev_from( $sentence_ref, "noun", $last_index );

        # fallback
        if ( $sentence_ref->[$i]{"parent"} == -1 ) {
            if ( $last_verb != $last_index ) {
                $sentence_ref->[$i]{"parent"} = $last_verb;

                #               print "for $i set parent to $last_verb\n";
                $pred_index = $last_verb;
            }
            elsif ( $last_noun != $last_index ) {
                $sentence_ref->[$i]{"parent"} = $last_noun;

                #               print "for $i set parent to $last_noun\n";
                $pred_index = $last_noun;
            }
            else {
                $sentence_ref->[$i]{"parent"} = -1;

                #               print "for $i set parent to -1\n";
            }
        }
    }

    # predicate -- will be changed to 0 afterwards
    if ( $sentence_ref->[$pred_index]{"parent"} != -1 ) {
        my $pred_parent = $sentence_ref->[$pred_index]{"parent"};

        #       print "for $pred_index set parent to -1\n";
        $sentence_ref->[$pred_parent]{"parent"} = -1;
    }

    #       $sentence_ref->[$first_verb]{"parent"} = -1;

    my @parents;
    for ( my $i = 0; $i < @{$sentence_ref}; $i++ ) {
        if ( $i != @{$sentence_ref} - 1 ) {
            push( @parents, $sentence_ref->[$i]{"parent"} + 1 );    # position plus one, because we count from 0, tred and others count from 1
        }
        else {
            push( @parents, $sentence_ref->[$i]{"parent"} );        #   last one must remain 0
        }
    }

    #   for(my $i = 0; $i < @{$sentence_ref}; $i++) {
    #       my $current_tag = $sentence_ref->[$i]{"tag"};
    #       my $current_form = $sentence_ref->[$i]{"form"};
    #       my $current_parent = $parents[$i];
    #       my $i_plus = $i + 1;
    #       print("$i_plus: $current_form\t$current_tag\t$current_parent\n");
    #   }
    #
    #   print "\n";

    return @parents;

}

1;

__END__

=head1 NAME

Parser::Simple::FR - Perl module for tagging French

=head1 SYNOPSIS

  use Treex::Tool::Parser::Simple::FR;
  my $parser = Treex::Tool::Parser::Simple::FR->new();
  my @words  = qw(Alors la Sagesse changea de méthode et parla d'enquête et d'espionnage.);
  my @tags = qw(adv art noun verb prep verb conj verb verb conj noun); 
  my @parents = $parser->parse_sentence(\@words,\@lemmas_not_needed,\@tags);
  while (@words) {
      print shift @words,"\t",shift @parents,"\n";
  }

=head1 COPYRIGHT AND LICENCE

Copyright 2010-2011 Peter Fabian, Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
