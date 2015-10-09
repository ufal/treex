package Treex::Tool::Gazetteer::Features;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

sub extract_feats {
    my ($match) = @_;

    my @feats = ();

    my @anodes = @{$match->[2]};
    my @forms = map {$_->form} @anodes;

    my $full_str = join " ", @forms;
    
    my $full_str_eq = ($full_str eq $match->[1]) ? 1 : 0;
    push @feats, ['full_str_eq', $full_str_eq];

    my $non_alpha = ($full_str !~ /[a-zA-Z]/) ? 1 : 0;
    push @feats, ['full_str_non_alpha', $non_alpha];

    my $first_starts_capital = ($forms[0] =~ /^\p{IsUpper}/) ? 1 : 0;
    push @feats, ['first_starts_capital', $first_starts_capital];
    
    my $entity_starts_capital = ($match->[1] =~ /^\p{IsUpper}/) ? 1 : 0;
    push @feats, ['entity_starts_capital', $entity_starts_capital];

    my $all_start_capital = (all {$_ =~ /^\p{IsUpper}/} @forms) ? 1 : 0;
    push @feats, ['all_start_capital', $all_start_capital];
    
    my $no_first = (all {$_->ord > 1} @anodes) ? 1 : 0;
    push @feats, ['no_first', $no_first];

    my $last_menu = ($forms[$#forms] eq "menu") ? 1 : 0;
    push @feats, ['last_menu', $last_menu];

    my $all_capital = 
        (($match->[1] !~ /\p{IsLower}/) || (all {$_ !~ /\p{IsLower}/} @forms)) ? 1 : 0;
    push @feats, ['all_capital', $all_capital];

    my $context_size = 3;
    my $next_node = $anodes[$#anodes]->get_next_node;
    my $prev_node = $anodes[0]->get_prev_node;
    for (my $i=0; $i<$context_size; $i++) {
        if (defined $next_node) {
            push @feats, ['next_form', $next_node->form];
            push @feats, ['next_form_'.($i+1), $next_node->form];
            $next_node = $next_node->get_next_node;
        }
        if (defined $prev_node) {
            push @feats, ['prev_form', $prev_node->form];
            push @feats, ['prev_form_'.($i+1), $prev_node->form];
            $prev_node = $prev_node->get_prev_node;
        }
    }

    push @feats, ['anode_count', scalar @anodes];

    return \@feats;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Gazetteer::Features

=head1 DESCRIPTION

Features for gazetteer entity recognition.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
