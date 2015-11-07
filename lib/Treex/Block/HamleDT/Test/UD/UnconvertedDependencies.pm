package Treex::Block::HamleDT::Test::UD::UnconvertedDependencies;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

# 40 universal dependency relations
my @relations =
(
    'nsubj', 'nsubjpass', 'dobj', 'iobj', 'csubj', 'csubjpass', 'ccomp', 'xcomp',
    'nmod', 'advmod', 'advcl', 'neg',
    'vocative', 'discourse', 'expl', 'aux', 'auxpass', 'cop', 'mark',
    'appos', 'amod', 'det', 'nummod', 'acl', 'case',
    'compound', 'mwe', 'name', 'goeswith', 'foreign',
    'conj', 'cc', 'punct',
    'list', 'dislocated', 'parataxis', 'remnant', 'reparandum',
    'root', 'dep'
);

# additional language-specific relations
my %lspecrel =
(
    'ar'  => ['advmod:emph'],
    'cs'  => ['advmod:emph', 'auxpass:reflex', 'det:numgov', 'det:nummod', 'nummod:gov'],
    'da'  => ['acl:relcl', 'compound:prt', 'nmod:loc', 'nmod:poss', 'nmod:tmod'],
    'de'  => ['nmod:poss'],
    'el'  => ['acl:relcl'],
    'en'  => ['acl:relcl', 'cc:preconj', 'compound:prt', 'det:predet', 'nmod:npmod', 'nmod:poss', 'nmod:tmod'],
    'es'  => ['acl:relcl'],
    'et'  => ['advmod:emph', 'compound:prt', 'nummod:gov'],
    'fa'  => ['acl:relcl', 'compound:lvc', 'compound:prt', 'det:predet', 'nmod:poss', 'nsubj:nc'],
    'fi'  => ['acl:relcl', 'advcl:compar', 'cc:preconj', 'compound:nn', 'compound:prt', 'csubj:cop', 'mark:comparator', 'nmod:gobj', 'nmod:gsubj', 'nmod:own', 'nmod:poss', 'nsubj:cop', 'xcomp:ds'],
    'fr'  => ['acl:relcl', 'nmod:poss'],
    'ga'  => ['acl:relcl', 'case:voc', 'compound:prt', 'csubj:cleft', 'csubj:cop', 'mark:prt', 'nmod:poss', 'nmod:prep', 'nmod:tmod', 'xcomp:pred'],
    'grc' => ['advmod:emph'],
    'he'  => ['acl:inf', 'acl:relcl', 'advmod:inf', 'advmod:phrase', 'aux:q', 'case:acc', 'case:gen', 'conj:discourse', 'det:def', 'det:quant', 'nmod:poss', 'nmod:smixut', 'nmod:tmod', 'nsubj:cop'],
    'hi'  => ['acl:relcl'],
    'hu'  => ['advmod:locy', 'advmod:mode', 'advmod:obl', 'advmod:que', 'advmod:tfrom', 'advmod:tlocy', 'advmod:to', 'advmod:tto', 'amod:att', 'amod:attlvc', 'amod:mode', 'amod:obl', 'ccomp:obj', 'ccomp:obl', 'ccomp:pred', 'compound:preverb', 'dobj:lvc', 'name:hu', 'nmod:att', 'nmod:attlvc', 'nmod:obl', 'nmod:obllvc', 'nsubj:lvc'],
    'it'  => ['acl:relcl', 'det:poss', 'det:predet', 'expl:impers'],
    'la'  => ['advmod:emph', 'auxpass:reflex'],
    'nl'  => ['compound:prt', 'det:nummod'],
    'no'  => ['acl:relcl', 'compound:prt'],
    'pl'  => [],
    'pt'  => ['advmod:emph', 'auxpass:reflex'],
    'ro'  => ['advcl:tcl', 'advcl:tmod', 'advmod:tmod', 'cc:preconj', 'expl:impers', 'expl:pass', 'expl:poss', 'expl:pv', 'nmod:agent', 'nmod:pmod', 'nmod:tmod'],
    'sl'  => ['cc:preconj'],
    'sv'  => ['acl:relcl', 'compound:prt', 'nmod:agent', 'nmod:poss'],
    'ta'  => ['advmod:emph', 'compound:prt'],
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
