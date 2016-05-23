package Treex::Block::A2A::CS::DoubleNegation;
use Moose;
use Treex::Core::Common;
use utf8;
use List::Util "sum";
extends 'Treex::Core::Block';

has denegate => ( is => 'rw', isa => 'Bool', default => 0 );

my %negators = (
    'nic' => 1,
    'nikdo' => 1,
    'ničí' => 1,
    'nikde' => 1,
    'nikam' => 1,
    'nikudy' => 1,
    'odnikud' => 1,
    'nijak' => 1,
    'nijaký' => 1,
    'žádný' => 1,
    'nikdy' => 1,
);

use Treex::Tool::LM::MorphoLM;
my $morphoLM;

sub process_start {
    my $self = shift;
    $morphoLM  = Treex::Tool::LM::MorphoLM->new();
    $self->SUPER::process_start();
    return;
}

sub process_anode {
    my ($self, $anode) = @_;

    if ($negators{$anode->lemma}) {
        my $result = $self->process($anode);
        log_info(
            ($result ? 'Succeeded to ' : 'Failed to ')
            . ($self->denegate ? 'denegate' : 'negate')
            . ' parental verb of ' . $anode->id
            . ' (' . $anode->form . ')'
            . ' in sentence: '
            . (join ' ',
                map { $_->form }
                    $anode->get_root->get_descendants({ordered => 1})
            )
        );
    }

    return;
}

sub process {
    my ($self, $anode) = @_;

    if ($anode->is_root) {
        return 0;
    } elsif ($anode->tag !~ /^V/) {
        # Non-verb -- go up in tree
        my $result = 0;
        foreach my $eparent ($anode->get_eparents) {
            # Do not cross quoted speech boundaries
            my @quotes = grep { $_->form =~ /^[„"“”"‚‘’']$/ } $anode->get_nodes_between($eparent);
            if (scalar(@quotes) % 2) {
                next;
            }
            $result += $self->process($eparent);
        }
        return $result;
    } else {
        # Anything except for past verbs takes negation on AuxV children
        # (unless there are none)
        if ($anode->tag !~ /^Vp/) {
            my @echildren = grep { $_->afun eq 'AuxV' && $_->tag !~ /^Vc/ } $anode->get_echildren;
            if (@echildren) {
                return $self->flip_list(\@echildren);
            }
        }

        # Infinitives and passives take negation on verb parents
        # (unless there are none)
        if ($anode->tag =~ /^V[fs]/) {
            my @eparents = grep { $_->tag =~ /^V[^s]/ } $anode->get_eparents;
            if (@eparents) {
                return $self->flip_list(\@eparents);
            }
        }
        
        # Finally, any verb can take negation on itself
        return $self->flip($anode);
    }
}

sub flip_list {
    my ($self, $list) = @_;

    my $result = 0;
    foreach my $item (@$list) {
        $result += $self->flip($item);
    }
    return $result;
    
    # Should be equivalent to the following one-liner:
    #   return sum { map { $self->flip($_) } @$list };
    # but in fact this sometimes leads to:
    # 'Odd number of elements in anonymous hash'
    # amd I don't know why and I probably don't want to know.
}

sub flip {
    my ($self, $anode) = @_;

    # TODO switch "smět" <-> "muset"?

    # Generate tag and baseline form
    my $tag = $anode->tag;
    my $form;
    if ($self->denegate) {
        if ($tag =~ /^.{10}N/) {
            # Denegate
            substr $tag, 10, 1, 'A';
            $form = lc (substr $anode->form, 2);
        } else {
            # Not negated
            return 0;
        }
    } else {
        if ($tag =~ /^.{10}A/) {
            # Negate
            substr $tag, 10, 1, 'N';
            $form = lc ('ne' . $anode->form);
        } else {
            # Already negated
            return 0;
        }
    }

    # Generate proper form, if possible
    my $form_info = $morphoLM->best_form_of_lemma($anode->lemma, $tag);
    if ($form_info) {
        $form = $form_info->get_form();
    }

    # Correctly capitalize the form
    if ($anode->form eq uc $anode->form) {
        $form = uc $form;
    } elsif ($anode->form eq ucfirst lc $anode->form) {
        $form = ucfirst $form;
    }

    # Set form and tag
    $anode->set_form($form);
    $anode->set_tag($tag);
    
    return 1;
}

1;

=head1 NAME 

Treex::Block::A2A::CS::DoubleNegation -- add or remove negation on verb in double negation clauses

=head1 SYNOPSIS

 # Strip negation from text
 treex -Lcs Read::Sentences Scen::Analysis::CS::M Scen::Analysis::CS::A A2A::CS::DoubleNegation denegate=1 A2W::Detokenize remove_final_space=1 Write::Sentences < in.txt > denegated.txt

 # Restore negation in text (ideally should generate text identical to in.txt)
 treex -Lcs Read::Sentences Scen::Analysis::CS::M Scen::Analysis::CS::A A2A::CS::DoubleNegation A2W::Detokenize remove_final_space=1 Write::Sentences < denegated.txt > negated.txt

=head1 DESCRIPTION

Conversion between Czech double negation ("nikdo nepřišel") and English-style negation ("nikdo přišel").

Find a negator (e.g. nic, nikdo, žádný...),
find its corresponding parent verb to bear the secondary negation,
and then either add or strip its negation
(based on the value of the C<denegate> parameter).

TODO: handle missing verb cases (but how to detect that? guess from commas?):
"Už bylo pět hodin, a pořád nic."
Sometimes, this is marked by "ne" particle:
Podstoupil zápas i s draky, ale nikdy ne s drakem tak silným v magii, jako byla tahle bezkřidlá vzteklá bestie.

TODO: handle negation on deverbal adjectives (tag AG....):
"Jediné, co bude dneska obětováno je srdce určitého nic netušícího barmana."

TODO: what to do with triple negation?
"Nikdy nic nepodepisujte."
Options (all bad):
"Nikdy nic podepisujte." (current)
"Nikdy něco podepisujte." / "Někdy nic podepisujte." / ... (unclear, too many options)
"Nikdy nic nepodepisujte." (keep)

TODO: filter phrases, such as "zničeho nic", "odnikud nikam"

=head1 PARAMETERS

=over

=item denegate

If C<denegate=1>, strips negation.

If C<denegate=0> (default), adds negation.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

