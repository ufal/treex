package Treex::Block::HamleDT::Test::UD::UnconvertedDependencies;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

# 40 universal dependency relations
my @relations =
(
    'nsubj', 'nsubj:pass', 'obj', 'iobj', 'csubj', 'csubj:pass', 'ccomp', 'xcomp',
    'obl', 'obl:agent', 'obl:tmod', 'advmod', 'advmod:emph', 'advcl',
    'vocative', 'discourse', 'expl', 'expl:pv', 'expl:pass', 'expl:impers', 'aux', 'aux:pass', 'cop', 'mark', 'mark:relcl',
    'appos', 'nmod', 'nmod:poss', 'amod', 'det', 'det:predet', 'nummod', 'acl', 'acl:relcl', 'case', 'clf',
    'compound', 'fixed', 'flat', 'flat:foreign', 'flat:name', 'goeswith',
    'conj', 'cc', 'punct',
    'list', 'dislocated', 'parataxis', 'orphan', 'reparandum',
    'root', 'dep'
);

# additional language-specific relations
my %lspecrel =
(
    'ar'  => [],
    'ca'  => ['det:nummod', 'expl:pass'],
    'cs'  => ['det:numgov', 'det:nummod', 'nummod:gov'],
    'da'  => ['compound:prt', 'nmod:loc', 'nmod:poss', 'nmod:tmod'],
    'de'  => ['nmod:poss'],
    'el'  => [],
    'en'  => ['cc:preconj', 'compound:prt', 'det:predet', 'nmod:npmod', 'nmod:poss', 'nmod:tmod'],
    'es'  => ['det:nummod'],
    'et'  => ['compound:prt', 'nummod:gov'],
    'fa'  => ['cc:preconj', 'compound:lvc', 'compound:prt', 'det:predet', 'nmod:poss', 'nsubj:nc'],
    'fi'  => ['advcl:compar', 'cc:preconj', 'compound:nn', 'compound:prt', 'csubj:cop', 'mark:comparator', 'nmod:gobj', 'nmod:gsubj', 'nmod:own', 'nmod:poss', 'nsubj:cop', 'xcomp:ds'],
    'fr'  => ['nmod:poss'],
    'ga'  => ['case:voc', 'compound:prt', 'csubj:cleft', 'csubj:cop', 'mark:prt', 'nmod:poss', 'nmod:prep', 'nmod:tmod', 'xcomp:pred'],
    'grc' => [],
    'he'  => ['acl:inf', 'advmod:inf', 'advmod:phrase', 'aux:q', 'case:acc', 'case:gen', 'conj:discourse', 'det:def', 'det:quant', 'nmod:poss', 'nmod:smixut', 'nmod:tmod', 'nsubj:cop'],
    'hi'  => ['compound:conjv', 'compound:redup'],
    'hu'  => ['advmod:locy', 'advmod:mode', 'advmod:obl', 'advmod:que', 'advmod:tfrom', 'advmod:tlocy', 'advmod:to', 'advmod:tto', 'amod:att', 'amod:attlvc', 'amod:mode', 'amod:obl', 'ccomp:obj', 'ccomp:obl', 'ccomp:pred', 'compound:preverb', 'obj:lvc', 'flat:hu', 'nmod:att', 'nmod:attlvc', 'nmod:obl', 'nmod:obllvc', 'nsubj:lvc'],
    'it'  => ['det:poss', 'det:predet'],
    'la'  => [],
    'nl'  => ['compound:prt', 'det:nummod'],
    'no'  => ['compound:prt'],
    'pl'  => ['det:numgov', 'det:nummod', 'nummod:gov'],
    'pt'  => ['acl:inf', 'acl:part', 'det:poss', 'xcomp:adj'],
    'ro'  => ['advcl:tcl', 'advcl:tmod', 'advmod:tmod', 'cc:preconj', 'expl:poss', 'nmod:agent', 'nmod:pmod', 'nmod:tmod'],
    'sl'  => ['cc:preconj'],
    'sv'  => ['compound:prt', 'nmod:agent', 'nmod:poss'],
    'ta'  => ['compound:prt'],
    'ug'  => ['advcl:cond', 'advmod:emph', 'aux:q', 'compound:lvc', 'compound:redup', 'conj>advcl', 'conj>obj', 'conj>obj:cau', 'conj>nmod', 'conj>nsubj', 'obj:cau', 'nmod:abl', 'nmod:cau', 'nmod:clas', 'nmod:cmp', 'nmod:ins', 'nmod:loc', 'nmod:part', 'nmod:pass', 'nmod:poss', 'nmod:ref', 'nmod:tmod', 'nsubj:cop'],
    'zh'  => ['case:loc', 'discourse:sp', 'mark:adv', 'obl:patient'],
    'xx'  => [],
);

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $deprel = $node->deprel();
    # The tests are usually run for many languages at once, and the block parameter language is not set.
    # Let's ask the zone instead.
    my $language = $node->get_zone()->language();
    my @lspecrel;
    if(exists($lspecrel{$language}))
    {
        @lspecrel = @{$lspecrel{$language}};
    }
    else
    {
        @lspecrel = @{$lspecrel{xx}};
    }
    my @allrel = (@relations, @lspecrel);
    #if($deprel =~ m/^dep:.*$/)
    unless(any {$_ eq $deprel} (@allrel))
    {
        $self->complain($node, $deprel);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::UnconvertedDependencies

If the Prague-to-UD conversion fails to convert an afun, the value will propagate
to the output data as an extension of C<dep>. For example, in the beginning we
were not able to convert C<AuxA>, which was not an official HamleDT 2.0 afun
but it appeared in the data anyway. It got to UD as C<dep:auxa>.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
