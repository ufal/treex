package Treex::Block::T2A::RU::ChooseMlemmaForPersPron;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( $tnode->t_lemma eq '#PersPron' ) {
        my $mlemma;
        my ($gender,$number,$person) = map {$tnode->get_attr("gram/$_")} qw(gender number person);

        if ( $tnode->formeme =~ /^adj/ ) { # in adjectival positions

            if ($person eq '1') {
                $mlemma = $number eq 'sg' ? 'мой' : 'наш';
            }
            elsif ($person eq '2') {
                $mlemma = $number eq 'sg' ? 'твой' : 'ваш';
            }
            else {
                if ($number eq 'pl') {
                    $mlemma = 'их';
                } else {
                    if ($gender eq 'fem') {
                        $mlemma = 'её';
                    } else {
                        $mlemma = 'его';
                    }
                }
            }
        }
        else {            # in noun-like positions
            if ($person eq '1') {
                $mlemma = $number eq 'sg' ? 'я' : 'мы';
            }
            elsif ($person eq '2') {
                $mlemma = $number eq 'sg' ? 'ты' : 'вы';
            }
            else {
                if ($number eq 'pl') {
                    $mlemma = 'они';
                } else {
                    if ($gender eq 'fem') {
                        $mlemma = 'она';
                    }
                    elsif ($gender eq 'neut') {
                        $mlemma = 'оно';
                    }
                    else {
                        $mlemma = 'он';
                    }
                }
            }
        }

        if ( $mlemma ) {
            my $anode =  $tnode->get_lex_anode();
            $anode->set_lemma($mlemma);
            $anode->set_form($mlemma);
            $anode->set_attr('morphcat/person','.');
        }

    }

    return;
}

1;

=over

=item Treex::Block::T2A::RU::ChooseMlemmaForPersPron

Attribute C<lemma> of a-nodes corresponding to #PersPron is
set accordingly to formeme, person, number and gender.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
