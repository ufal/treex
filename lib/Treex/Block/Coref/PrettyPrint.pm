package Treex::Block::Coref::PrettyPrint;
use Moose;
use Treex::Core::Common;
use Term::ANSIColor;

use Treex::Tool::Coreference::Utils;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.txt' );
has '_ord_of_ttree'  => ( is => 'rw', isa => 'HashRef', default => sub{{}} );
has '_key_sents_for' => ( is => 'rw', isa => 'HashRef', default => sub{{}} );
has '_sys_sents_for' => ( is => 'rw', isa => 'HashRef', default => sub{{}} );

before 'process_document' => sub {
    my ($self, $doc) = @_;
    my @ttrees = map {$_->get_tree($self->language, 't', $self->selector)} $doc->get_bundles;
    my %ord_of_ttree = map {$ttrees[$_]->id => $_} 0 .. $#ttrees;
    $self->_set_ord_of_ttree(\%ord_of_ttree);
    $self->_set_key_sents_for({});
    $self->_set_sys_sents_for({});
};

sub _coref_format {
    my ($sents, $anaph_id) = @_;

    my $is_correct = 0;
    my $has_sys_ante = 0;
    my $has_key_ante = 0;

    my @words = ();
    foreach my $ttree (@$sents) {
        foreach my $tnode ($ttree->get_descendants({ordered => 1})) {
            my @colors = ();
            if ($tnode->id eq $anaph_id) {
                push @colors, "yellow";
            }
            if ($tnode->wild->{coref_diag}{cand_for}{$anaph_id}) {
                push @colors, "reverse";
            }
            if ($tnode->wild->{coref_diag}{sys_ante_for}{$anaph_id} && $tnode->wild->{coref_diag}{key_ante_for}{$anaph_id}) {
                push @colors, "green";
                $is_correct = 1;
                $has_key_ante = 1;
                $has_sys_ante = 1;
            }
            elsif ($tnode->wild->{coref_diag}{key_ante_for}{$anaph_id}) {
                push @colors, "cyan";
                $has_key_ante = 1;
            }
            elsif ($tnode->wild->{coref_diag}{sys_ante_for}{$anaph_id}) {
                push @colors, "red";
                $has_sys_ante = 1;
            }

            my $anode = $tnode->get_lex_anode;
            my $word = defined $anode ? $anode->form : $tnode->t_lemma;
            if (@colors) {
                $word = color(join " ", @colors) . $word . color("reset");
            }
            push @words, $word;
        }
    }
    if (!$has_sys_ante && !$has_key_ante) {
        $is_correct = 1;
    }
    my $str = $is_correct ? "OK:\t" : "ERR:\t";
    $str .= join " ", @words;
    return $str;
}

sub process_ttree {
    my ($self, $ttree) = @_;

    my %key_ante_for = ();
    my %sys_ante_for = ();

    foreach my $tnode ($ttree->get_descendants({ordered => 1})) {
        my $coref_diag = $tnode->wild->{coref_diag};
        next if (!defined $coref_diag);
        foreach my $anaph_id (keys %{$coref_diag->{key_ante_for} || {}}) {
            $key_ante_for{$anaph_id} = 1;
        }
        foreach my $anaph_id (keys %{$coref_diag->{sys_ante_for} || {}}) {
            $sys_ante_for{$anaph_id} = 1;
        }
    }
    
    foreach my $anaph_id (keys %key_ante_for) {
        $self->_key_sents_for->{$anaph_id} = $ttree;
    }
    foreach my $anaph_id (keys %sys_ante_for) {
        $self->_sys_sents_for->{$anaph_id} = $ttree;
    }
        
    foreach my $tnode ($ttree->get_descendants({ordered => 1})) {
        my $coref_diag = $tnode->wild->{coref_diag};
        if ($coref_diag->{is_anaph}) {

            my %sents = ();
            my $key_ttree = delete $self->_key_sents_for->{$tnode->id};
            $sents{$key_ttree->id} = $key_ttree if (defined $key_ttree);
            my $sys_ttree = delete $self->_sys_sents_for->{$tnode->id};
            $sents{$sys_ttree->id} = $sys_ttree if (defined $sys_ttree);
            $sents{$ttree->id} = $ttree;

            my @sorted_sents = sort {$self->_ord_of_ttree->{$a->id} <=> $self->_ord_of_ttree->{$b->id}} values %sents;
            my @diffs = map {$self->_ord_of_ttree->{$sorted_sents[$_+1]->id} - $self->_ord_of_ttree->{$sorted_sents[$_]->id} - 1} 0..$#sorted_sents-1;

            print {$self->_file_handle} $tnode->get_address;
            print {$self->_file_handle} "\n";
            print {$self->_file_handle} join " ", map {
                my $sent = $sorted_sents[$_]->get_zone->sentence;
                if ($diffs[$_]) {
                    $sent .= " ...".$diffs[$_]."...";
                }
                $sent} 0..$#sorted_sents;
            print {$self->_file_handle} "\n";
            print {$self->_file_handle} _coref_format(\@sorted_sents, $tnode->id);
            print {$self->_file_handle} "\n";
            print {$self->_file_handle} "\n";
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
