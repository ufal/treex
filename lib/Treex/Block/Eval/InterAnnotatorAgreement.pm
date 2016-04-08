package Treex::Block::Eval::InterAnnotatorAgreement;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );



#------------------------------------------------------------------------------
# Counts nonprojective dependencies in the a-tree of a zone.
#------------------------------------------------------------------------------
sub process_document
{
    my $self = shift;
    my $document = shift;
    my @bundles = $document->get_bundles();
    for(my $ib = 0; $ib<=$#bundles; $ib++)
    {
        my $keep = 0;
        my $bundle = $bundles[$ib];
        my $z1 = $bundle->get_zone($self->language(), 'annotator1');
        my $z2 = $bundle->get_zone($self->language(), 'annotator2');
        my $root1 = $z1->get_atree();
        my $root2 = $z2->get_atree();
        my @nodes1 = $root1->get_descendants({'ordered' => 1});
        my @nodes2 = $root2->get_descendants({'ordered' => 1});
        my $n1 = scalar(@nodes1);
        my $n2 = scalar(@nodes2);
        if($n1 != $n2)
        {
            print("unmatched_sentence_length\t1\n");
        }
        elsif($n1 < 2)
        {
            print("sentence_too_short\t1\n");
        }
        else
        {
            my $ok = 1;
            for(my $i = 0; $i < $n1; $i++)
            {
                if(is_empty($nodes1[$i]->form()) || is_empty($nodes2[$i]->form()))
                {
                    print("empty_form\t1\n");
                    $ok = 0;
                }
                elsif($nodes1[$i]->form() ne $nodes2[$i]->form())
                {
                    print("unmatched_form\t1\n");
                }
                if(is_empty($nodes1[$i]->lemma()) || is_empty($nodes2[$i]->lemma()))
                {
                    print("empty_lemma\t1\n");
                    $ok = 0;
                }
                elsif($nodes1[$i]->lemma() ne $nodes2[$i]->lemma())
                {
                    print("unmatched_lemma\t1\n");
                }
                if(is_empty($nodes1[$i]->tag()) || is_empty($nodes2[$i]->tag()))
                {
                    print("empty_tag\t1\n");
                    $ok = 0;
                }
                elsif($nodes1[$i]->tag() ne $nodes2[$i]->tag())
                {
                    print("unmatched_tag\t1\n");
                }
                if(is_empty($nodes1[$i]->deprel()) || $nodes1[$i]->deprel() eq '???' || is_empty($nodes2[$i]->deprel()) || $nodes2[$i]->deprel() eq '???')
                {
                    print("empty_deprel\t1\n");
                    $ok = 0;
                }
            }
            # Compute the remaining statistics only on sentences that are "OK".
            if($ok)
            {
                print("sentence\t1\n");
                print("token\t$n1\n");
                my $lerror = 0;
                for(my $i = 0; $i < $n1; $i++)
                {
                    if($nodes1[$i]->parent()->ord() == $nodes2[$i]->parent()->ord())
                    {
                        print("uparent\t1\n");
                        my $d1 = $nodes1[$i]->deprel();
                        my $d2 = $nodes2[$i]->deprel();
                        $d1 .= '_M' if($nodes1[$i]->is_member());
                        $d2 .= '_M' if($nodes2[$i]->is_member());
                        if($d1 eq $d2)
                        {
                            print("lparent\t1\n");
                        }
                        else
                        {
                            print("unmatched_deprel\t1\n");
                            $lerror++;
                        }
                    }
                    else
                    {
                        print("unmatched_parent\t1\n");
                        $lerror++;
                    }
                }
                if($lerror == 0)
                {
                    print("complete_match\t1\n");
                    print("complete_match_token\t$n1\n");
                    $keep = 1;
                }
            }
        }
        if(!$keep)
        {
            # Remove all bundles that are not completely matched.
            # Due to this line the block might be in Filter instead of Eval.
            $bundles[$ib]->remove();
        }
    }
}



#------------------------------------------------------------------------------
# Checks whether a value is undefined or empty (except for whitespace).
#------------------------------------------------------------------------------
sub is_empty
{
    my $x = shift;
    return !defined($x) || $x =~ m/^\s*$/; # or '_'? But there may be a genuine '_' token.
}



1;

=over

=item Treex::Block::Eval::InterAnnotatorAgreement

Assumes two zones in the same language, annotator1 and annotator2.
Compares values of morphological and syntactic (analytical) attributes in the
two zones.

=back

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
