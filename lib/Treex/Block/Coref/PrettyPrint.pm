package Treex::Block::Coref::PrettyPrint;
use Moose;
use Treex::Core::Common;
use Term::ANSIColor;

use Treex::Tool::Coreference::Utils;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.txt' );
has '_sents_active_for' => ( is => 'rw', isa => 'HashRef', default => sub{{}} );

sub _coref_format {
    my ($sents, $anaph_id) = @_;

    my @words = ();
    foreach my $ttree (@$sents) {
        foreach my $tnode ($ttree->get_descendants({ordered => 1})) {
            my @colors = ();
            if ($tnode->id eq $anaph_id) {
                push @colors, "on_yellow";
            }
            if ($tnode->wild->{coref_diag}{cand_for}{$anaph_id}) {
                push @colors, "reverse";
            }
            if ($tnode->wild->{coref_diag}{sys_ante_for}{$anaph_id} && $tnode->wild->{coref_diag}{key_ante_for}{$anaph_id}) {
                push @colors, "green";
            }
            elsif ($tnode->wild->{coref_diag}{key_ante_for}{$anaph_id}) {
                push @colors, "cyan";
            }
            elsif ($tnode->wild->{coref_diag}{sys_ante_for}{$anaph_id}) {
                push @colors, "red";
            }

            my $anode = $tnode->get_lex_anode;
            my $word = defined $anode ? $anode->form : $tnode->t_lemma;
            if (@colors) {
                $word = color(join " ", @colors) . $word . color("reset");
            }
            push @words, $word;
        }
    }
    return join " ", @words;
}

sub process_ttree {
    my ($self, $ttree) = @_;

    my %active_for = ();

    foreach my $tnode ($ttree->get_descendants({ordered => 1})) {
        my $coref_diag = $tnode->wild->{coref_diag};
        next if (!defined $coref_diag);
        foreach my $anaph_id (keys %{$coref_diag->{cand_for} || {}}) {
            if (!$active_for{$anaph_id}) {
                $active_for{$anaph_id} = 1;
            }
        }
        
        if ($coref_diag->{is_anaph}) {
            delete $active_for{$tnode->id};

            my $sents = delete $self->_sents_active_for->{$tnode->id};
            push @$sents, $ttree;

            print {$self->_file_handle} $tnode->get_address;
            print {$self->_file_handle} "\n";
            print {$self->_file_handle} join " ", map {$_->get_zone->sentence} @$sents;
            print {$self->_file_handle} "\n";
            print {$self->_file_handle} _coref_format($sents, $tnode->id);
            print {$self->_file_handle} "\n";
            print {$self->_file_handle} "\n";
        }

    }

    foreach my $anaph_id (keys %active_for) {
        if (defined $self->_sents_active_for->{$anaph_id}) {
            push @{$self->_sents_active_for->{$anaph_id}}, $ttree;
        }
        else {
            $self->_sents_active_for->{$anaph_id} = [ $ttree ];
        }
    }


    
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Coref::PrettyPrint

=head1 DESCRIPTION

This module is used to pretty print the results of coreference resolution.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
