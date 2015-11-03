package Treex::Block::W2W::EstimateNoSpaceAfter;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

###!!! We currently do not touch quotation marks.
###!!! Some are language-dependent (e.g. English opening = Czech closing).
###!!! For the undirected ones ('""') it is not easy to tell whether they are opening or closing (the quote may span multiple sentences!)
my $lbr = '\(\[\{';
my $rbr = '\}\]\)';



sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i<$#nodes; $i++)
    {
        my $form = $nodes[$i]->form();
        $form = '' if(!defined($form));
        my $next_form = $nodes[$i+1]->form();
        $next_form = '' if(!defined($next_form));
        if($form      =~ m/^¡¿[$lbr]$/ ||
           $next_form =~ m/^[\.,;:!\?$rbr]$/)
        {
            $node->set_no_space_after(1);
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::EstimateNoSpaceAfter

=head1 DESCRIPTION

The C<no_space_after> attribute of nodes encodes whether the current token was
separated by a whitespace from the next token in the original sentence before
tokenization.

If this information is not available in the corpus, we can estimate it
according to usual typographical rules. It mostly affects punctuation symbols
attached to the previous or to the following token. Note however that it is not
completely language-independent (for example, quotation marks are attached to
the quoted contents in English but not in French). It is also not possible (or
at least not easy) to recover all contexts. If tokenization split decimal
numbers on the decimal point, we could make an error if we treat the decimal
point as a normal period.

This block only adds the C<no_space_after> flags but it never removes them.
It assumes that these flags have not been present in the text.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
