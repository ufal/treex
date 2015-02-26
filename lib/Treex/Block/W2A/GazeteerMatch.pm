package Treex::Block::W2A::GazeteerMatch;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

use Algorithm::AhoCorasick qw/find_all/;
use List::MoreUtils qw/none/;

extends 'Treex::Core::Block';

has 'phrase_list_path' => ( is => 'ro', isa => 'Str', default => 'data/models/gazeteer/en.app_labels.gaz.gz');
has '_phrase_list' => ( is => 'ro', 'isa' => 'HashRef[HashRef]', builder => '_build_phrase_list', lazy => 1);

sub _build_phrase_list {
    my ($self) = @_;

    my $path = require_file_from_share($self->phrase_list_path);
    open my $fh, "<:gzip:utf8", $path;

    my $phrase_list = {};

    while (my $line = <$fh>) {
        chomp $line;
        my ($id, $phrase) = split /\t/, $line;

        if (!defined $phrase_list->{lc($phrase)}) {
            my $hash = {id => $id, orig => $phrase};
            $phrase_list->{lc($phrase)} = $hash;
        }
    }

    return $phrase_list;
}

sub process_start {
    my ($self) = @_;
    $self->_phrase_list;
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my @anodes = $atree->get_children( {ordered => 1} );

    # find matches
    my $tokenized_sent = join " ", map {lc($_->form)} @anodes;
    my $matches = find_all(lc($tokenized_sent), keys $self->_phrase_list);
    return if (!$matches);

    # associate the matches to anodes
    my $entity_cands = _select_anodes_to_matches(\@anodes, $matches);

    # assess which candidates are likely to be entity phrases and return only the mutually exclusive ones
    my $entites = _resolve_entities($entity_cands);
    
    # transform the a-tree
    #TODO
}

sub _select_anodes_to_matches {
    my ($anodes, $matches_hash) = @_;

    my @entities = ();
    my @unproc_list = ();

    my $idx = 0;
    foreach my $anode (@$anodes) {
        my @new_unproc_list = ();
        foreach my $unproc (@unproc_list) {
            if ($unproc->[0] == $idx) {
                push @{$unproc->[1]}, $anode;
                push @entities, $unproc->[1];
            }
            elsif ($unproc->[1] > $idx) {
                push @{$unproc->[1]}, $anode;
                push @new_unproc_list, $unproc;
            }
            else {
                # remove from unprocessed
            }
        }
        @unproc_list = @new_unproc_list;
        my $matches = $matches_hash->{$idx};
        if (defined $matches) {
            push @unproc_list, map {[ $idx + length($_) + 1, [$anode] ]} @$matches;
        }
        $idx += length($anode->form) + 1;
    }

    return \@entities;
}

sub _resolve_entities {
    my ($entity_cands) = @_;

    my @scores = map {_score_entity($_)} @$entity_cands;
    my @accepted_idx = grep {$scores[$_] > 0} 0 .. $#scores;
    
    my @sorted_idx = sort {$scores[$b] <=> $scores[$a]} @accepted_idx;

    my %covered_anode = ();
    my @resolved_entities = ();
    foreach my $idx (@sorted_idx) {
        my $cand = $entity_cands->[$idx];
        if (none {$covered_anode{$_}} @$cand) {
            push @resolved_entities, $cand;
            $covered_anode->{$_->id} = 1 foreach (@$cand);
        }
    }

    return \@resolved_entities;
}


1;

__END__

=encoding utf-8

=head1 NAME

=item Treex::Block::W2A::GazeteerMatch

=head1 DESCRIPTION


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
