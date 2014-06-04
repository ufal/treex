package Treex::Block::HamleDT::Util::ExtractSurfaceNGrams;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_atree {
    my $self = shift;
    my $a_root = shift;
    my $language = $a_root->get_zone->language();
    $a_root->get_address() =~ m/(^.*)##/;
    my $file = $1;
    my (@forms, @IDs, @iset_feats);
    my @nodes = sort { $a->ord() <=> $b->ord() }
                       $a_root->get_descendants();
    for my $node ( @nodes ) {
        push @forms, $node->form();
        push @IDs, $node->get_attr('id');
        push @iset_feats, $node->get_iset_conll_feat() || 'pos=X';
    }
    print join("\t",
               $language, $file, join(' ',@forms), join(' ',@IDs),
               join(' ',@iset_feats),
           ), "\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Util::ExtractSurfaceNGrams;

=head1 DESCRIPTION

Prints surface ngrams with POS to the standard output.

=head1 AUTHOR

Jan Mašek <masek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
