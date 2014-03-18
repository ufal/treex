package Treex::Block::T2TAMR::CreateTAMRfromT;
# usage: treex Read::Treex from=csen.merged.treex.gz T2TAMR::CreateTAMRfromT language=cs Write::Treex to=csen.merged.with_tamr.treex.gz
use Moose;
use Unicode::Normalize;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has '+selector'       => ( required => 1, isa => 'Str', default => 'amrClonedFromT' );
has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );

# TODO: copy attributes in a cleverer way
my @ATTRS_TO_COPY = qw(ord t_lemma functor);

  # simply use the following in place of AMR modifier
my %modifier_is_ftor = map {($_, 1)} qw(COORD APOS PAR DENOM VOCAT);
  # deterministically map the following
my %modifier_from_ftor = qw(
ACT  	ARG0
PAT  	ARG1
ADDR 	ARG2
ORIG 	ARG3
EFF  	ARG4
TWHEN	time
THL  	duration
DIR1 	source
DIR3 	direction
DIR2 	location
LOC  	location
BEN  	beneficiary
ACMP 	accompanier
MANN 	manner
AIM  	purpose
CAUS 	cause
MEANS	instrument
APP  	poss
CMP  	compared-to
RSTR 	mod
EXT  	scale
);

sub _build_source_selector {
    my ($self) = @_;
    return $self->selector;
}

sub _build_source_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->source_language && $self->selector eq $self->source_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

sub process_document {
    my ( $self, $document ) = @_;

    # the forward links (from source to target nodes) must be kept so that coreference links are copied properly
    my %src2tgt;

    foreach my $bundle ( $document->get_bundles() ) {
        print STDERR "Converting sentence ", $bundle->id(), "\n";
        $src2tgt{'varname_used'} = undef; # fresh namespace
        my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
        my $source_root = $source_zone->get_ttree;

        my $target_zone = $bundle->get_or_create_zone( $self->language, $self->selector );
        my $target_root = $target_zone->create_ttree( { overwrite => 1 } );

        copy_subtree( $source_root, $target_root, \%src2tgt );
        $target_root->set_src_tnode($source_root);
    }

    # copying coreference links
    foreach my $bundle ( $document->get_bundles() ) {
        print STDERR "Copying coref for ", $bundle->id(), "\n";
        my $target_zone = $bundle->get_zone( $self->language, $self->selector );
        my $target_root = $target_zone->get_ttree();
        foreach my $t_node ( $target_root->get_descendants ) {
            my $src_tnode  = $t_node->src_tnode;
            next if !defined $src_tnode;
              # can happen for e.g. the generated polarity node
            my $coref_gram = $src_tnode->get_deref_attr('coref_gram.rf');
            my $coref_text = $src_tnode->get_deref_attr('coref_text.rf');
            my @nodelist = ();
            if ( defined $coref_gram ) {
                push @nodelist, map { $src2tgt{'nodemap'}->{$_} } @$coref_gram;
            }
            if ( defined $coref_text ) {
                push @nodelist, map { $src2tgt{'nodemap'}->{$_} } @$coref_text;
            }
            $t_node->set_deref_attr( 'coref_text.rf', \@nodelist )
              if 0< scalar(@nodelist);
        }
    }
}

sub copy_subtree {
    my ( $source_root, $target_root, $src2tgt ) = @_;

    foreach my $source_node ( $source_root->get_children( { ordered => 1 } ) ) {
        my $target_node = $target_root->create_child();

        $src2tgt->{'nodemap'}->{$source_node} = $target_node;

        # copying attributes
        # t_lemma gets assigned a unique variable name
        my $tlemma = $source_node->get_attr('t_lemma');
        my $varname = firstletter($tlemma);
        if (defined $src2tgt->{'varname_used'}->{$varname}) {
          $src2tgt->{'varname_used'}->{$varname}++;
          $varname .= $src2tgt->{'varname_used'}->{$varname};
        } else {
          $src2tgt->{'varname_used'}->{$varname} = 1;
        }
        $target_node->set_attr('t_lemma', $varname."/".$tlemma);

        # the original functor serves as 
        $target_node->wild->{'modifier'} = make_default_modifier($source_node);

        $target_node->set_src_tnode($source_node);
        $target_node->set_t_lemma_origin('clone');

        # create polarity - for negated nodes
        my $neg = $source_node->get_attr('gram/negation');
        if (defined $neg && $neg eq "neg1") {
          # create AMR auxiliary node indicating negation
          my $negnode = $target_node->create_child();
          $negnode->set_attr('t_lemma', "-");
          $negnode->wild->{'modifier'} = "polarity";
        }

        copy_subtree( $source_node, $target_node, $src2tgt );
    }
}

sub make_default_modifier {
  # given a t-node, maps its functor to the AMR modifier using Zdenka's
  # heuristics
  my $node = shift;
  my $ftor = $node->get_attr('functor');

  # don't translate some functors
  return $ftor if $modifier_is_ftor{$ftor};

  if ($node->get_attr('is_member')) {
    # this should be an op1, op2, ...
    # process the whole coordination at once
    my $parent = $node->parent;
    if (!defined $node->wild->{'AMR_op_number'}) {
      # walk all members in the coord
      my $i = 1;
      foreach my $sibl ($parent->get_coap_members({direct_only=>1, ordered=>1})) {
        $sibl->wild->{'AMR_op_number'} = $i;
        $i++;
      }
    }
    my $opnr = $node->wild->{'AMR_op_number'};
    return "op".$opnr;
  }

  my $modif = $modifier_from_ftor{$ftor};
  return $modif if defined $modif; # use the default mapping

  # final options
  return "time" if $ftor =~ /^T/;
  return "ARGm";
}


sub firstletter {
  my $str = shift;
  $str = NFD( $str );   ##  decompose
  $str =~ s/\pM//g;         ##  strip combining characters
  $str =~ tr/ıł/il/;  ## other chars I spotted
  $str =~ s/[“”«»]/"/g; ## simplify quotes
  $str =~ s/[’]/'/g; ## simplify apostrophes
  $str =~ s/[—]/-/g; ## simplify dashes
  $str =~ s/±/+-/g; ## simplify plusminus
  # skip non-letters
  $str =~ s/^[^[:alpha:]]*//;
  return "X" if $str eq "";
  return lc(substr($str, 0, 1));
}


1;

=over

=item Treex::Block::T2TAMR::CopyTtree

This block copies tectogrammatical tree into another zone and 
Attributes 'a/lex.rf' and 'a/aux.rf' are not copied within the nodes.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
