package Treex::Block::Print::TokenStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

sub build_language { return log_fatal "Missing required parameter 'language'"; }

# Storage that accummulates information over all documents. Print summary in process_end().
has _stats => ( is => 'ro', default => sub { {} } );

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $stat = $self->_stats();
    # Investigate tokenization rules.
    # Look for unusual tokens.
    my $form = $node->form();
    if(defined($form))
    {
        if($form eq 'NULL')
        {
            $stat->{nnull}++;
        }
        # Count marks as equal to letters.
        # Mark characters include Arabic diacritical vowels.
        elsif($form =~ m/^(\pL|\pM)+$/)
        {
            $stat->{nletters}++;
        }
        elsif($form =~ m/^\pN+$/)
        {
            $stat->{ndigits}++;
        }
        elsif($form =~ m/^(\.|,|;|:|\?|!|\(|\)|")$/)
        {
            $stat->{ncommonpunc}++;
        }
        else
        {
            # We are interested in formats of decimal numbers but not in their values.
            $form =~ s/\d+/000/g;
            $stat->{forms}{$form}{n}++;
            if($stat->{forms}{$form}{n}==1)
            {
                $stat->{forms}{$form}{example} = $node->get_address();
            }
        }
    }
}

sub process_end
{
    my $self = shift;
    my $stat = $self->_stats();
    my $fh = $self->_file_handle();
    my @forms = keys(%{$stat->{forms}});
    my $ntypes = scalar(@forms);
    # Classify the special tokens in more detail.
    my ($nmne, $nmwe, $nhyp, $nabr, $nzwn, $noth);
    foreach my $form (@forms)
    {
        # The Persian treebank contains the ZERO WIDTH NON-JOINER.
        ###!!! DZ: I do not know what purpose it serves.
        ###!!! Update: Its usage is required by typographical and morphological rules.
        ###!!! It blocks usage of ligatures at certain places, e.g. between stem and plural suffix.
        ###!!! Instead of ligature, the preceding character will be in final and the following character in initial form.
        ###!!! So we probably want to count the ZWNJ among letters, although its category is "\pC"?
        if($form =~ m/\x{200C}/)
        {
            $stat->{forms}{$form}{type} = 'ZWN';
            $nzwn++;
        }
        # A multiword personal name? Contains an uppercase letter and an underscore.
        # Some treebanks (fa) use space inside of token instead of underscore.
        # May contain a period ("prof.", name initial).
        # Does not contain other punctuation and digits.
        elsif($form =~ m/\p{Lu}/ && $form =~ m/^(\pL|\pM|\.)+([_ ](\pL|\pM|\.)+)+$/)
        {
            $stat->{forms}{$form}{type} = 'MNE';
            $nmne++;
        }
        # Other multiword expression, no abbreviations (i.e. no period).
        # A typical example is a multiword preposition or conjunction (nl: zo_goed_als = "as good as").
        elsif($form =~ m/^(\pL|\pM)+(_(\pL|\pM)+)+$/)
        {
            $stat->{forms}{$form}{type} = 'MWE';
            $nmwe++;
        }
        # Compounds using hyphen(s).
        elsif($form =~ m/^(\pL|\pM)+(-(\pL|\pM)+)+$/)
        {
            $stat->{forms}{$form}{type} = 'HYP';
            $nhyp++;
        }
        # Abbreviations.
        elsif($form =~ m/^(\pL|\pM)(\pL|\pM|\.)*\.$/)
        {
            $stat->{forms}{$form}{type} = 'ABR';
            $nabr++;
        }
        # The rest is not classified.
        else
        {
            $stat->{forms}{$form}{type} = 'OTH';
            $noth++;
        }
    }
    # List the forms grouped by category.
    @forms = sort {my $r = $stat->{forms}{$a}{type} cmp $stat->{forms}{$b}{type}; unless($r) {$r = $a cmp $b} $r} (@forms);
    my $notokens = 0;
    foreach my $form (@forms)
    {
        my $type = $stat->{forms}{$form}{type};
        my $n = $stat->{forms}{$form}{n};
        my $example = $stat->{forms}{$form}{example};
        print {$fh} ("$type\t$form\t$n\t$example\n");
        $notokens += $n;
    }
    my $n = $stat->{nletters}+$stat->{ndigits}+$stat->{ncommonpunc}+$stat->{nnull}+$notokens;
    printf {$fh} ("TOTAL TOKENS                      \t%6d\n", $n);
    printf {$fh} ("TOTAL LETTER TOKENS               \t%6d (%.1f %%)\n", $stat->{nletters}, $stat->{nletters}/$n*100+0.01);
    printf {$fh} ("TOTAL DIGIT TOKENS                \t%6d (%.1f %%)\n", $stat->{ndigits}, $stat->{ndigits}/$n*100+0.01);
    printf {$fh} ("TOTAL COMMON PUNCTUATION          \t%6d (%.1f %%)\n", $stat->{ncommonpunc}, $stat->{ncommonpunc}/$n*100+0.01);
    printf {$fh} ("TOTAL NULL TOKENS                 \t%6d (%.1f %%)\n", $stat->{nnull}, $stat->{nnull}/$n*100+0.01);
    printf {$fh} ("TOTAL OTHER TOKENS                \t%6d (%.1f %%)\n", $notokens, $notokens/$n*100+0.01);
    printf {$fh} ("TOTAL OTHER TYPES (NUMBERS ZEROED)\t%6d\n", $ntypes);
    printf {$fh} ("  out of that: $nmne (%.1f %%) MNE, $nmwe (%.1f %%) MWE, $nhyp (%.1f %%) HYP, $nabr (%.1f %%) ABR, $nzwn (%.1f %%) ZWN and $noth (%.1f %%) OTH\n", $nmne/$ntypes*100+0.01, $nmwe/$ntypes*100+0.01, $nhyp/$ntypes*100+0.01, $nabr/$ntypes*100+0.01, $nzwn/$ntypes*100+0.01, $noth/$ntypes*100+0.01);
}

1;

=head1 NAME

Treex::Block::Print::TokenStats

=head1 DESCRIPTION

This block serves investigation of various tokenization schemes used in the treebanks.

=cut

# Copyright 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
