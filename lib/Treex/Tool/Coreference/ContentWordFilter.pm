package Treex::Tool::Coreference::ContentWordFilter;

use Moose;
use Treex::Core::Common;

# TODO the old style of NodeFilter: this should be moved to NodeFilter::ContentWord and added as an item to the new NodeFilter
with 'Treex::Tool::Coreference::NodeFilter';

my %en_nocontent_pos = map {$_ => 1} (
    'CC', 'CD', 'DT', 'EX', 'IN', 'LS', 'MD', 'PDT', 'POS',
    'PRP', 'PRP$', 'RP', 'SYM', 'TO', 'WDT', 'WP', 'WP$', 'WRB'
);

sub en_pos_filter {
    my ($anode) = @_;
    return defined $en_nocontent_pos{$anode->tag};
}

sub cs_pos_filter {
    my ($anode) = @_;
    return $anode->tag =~ /^[CJPRTZX]/;
}

# content word filtering
sub is_candidate {
    my ($self, $tnode) = @_;

    my $starts_with_hash = ($tnode->t_lemma =~ /^#/);
    my $is_gener = $tnode->is_generated;
    
    my $anode = $tnode->get_lex_anode;
    my $noncontent_pos = (defined $anode) && (
        $tnode->language eq 'en' ? en_pos_filter($anode) :
        $tnode->language eq 'cs' ? cs_pos_filter($anode) : 0);
    
    return (!$starts_with_hash && !$is_gener && !$noncontent_pos);
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::ContentWordFilter

=head1 DESCRIPTION

A filter for nodes that are content words.

=head1 METHODS

=item is_candidate

Returns whether the input node is a content word or not.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
