package Treex::Tool::Depfix::CS::FixLogger;
use Moose;
use Treex::Core::Common;
use utf8;

use Treex::Tool::Depfix::CS::PairGetter;

has 'language'       => ( is => 'rw', isa => 'Str', required => 1 );
has 'log_to_console' => ( is => 'rw', isa => 'Bool', default => 1 );

sub get_pair {
    my ($self, $node) = @_;

    return Treex::Tool::Depfix::CS::PairGetter::get_pair($node);
}

my $logfixmsg          = '';
my $logfixold          = '';
my $logfixnew          = '';
my $logfixbundle       = undef;
my $logfixs            = '';
my $logfixn            = '';
my $logfixold_flt_gov  = undef;
my $logfixold_flt_dep  = undef;
my $logfix_aligned_gov = undef;
my $logfix_aligned_dep = undef;

sub logfix1 {
    my ( $self, $node, $mess ) = @_;
    my ( $dep, $gov, $d, $g ) = $self->get_pair($node);

    $logfixmsg    = $mess;
    $logfixbundle = $node->get_bundle;
    {
        $node->id =~ /-s([0-9]+)-n([0-9]+)$/;
        $logfixs = $1;
        $logfixn = $2;
    }

    if ( $gov && $dep ) {

        $logfixold_flt_gov = $g->{flt};
        $logfixold_flt_dep = $d->{flt};

        # mark with alignment arrow

        my $cs_root = $node->get_bundle->get_tree(
            $self->language, 'a'
        );
        my @cs_nodes = $cs_root->get_descendants(
            {
                add_self => 1,
                ordered  => 1
            }
        );

        my $cs_gov = $cs_nodes[ $gov->ord ];
        if ( defined $cs_gov && $cs_gov->lemma eq $gov->lemma ) {
            $logfix_aligned_gov = $cs_gov;
        } else {
            $logfix_aligned_gov = undef;
        }

        my $cs_dep = $cs_nodes[ $dep->ord ];
        if ( defined $cs_dep && $cs_dep->lemma eq $dep->lemma ) {
            $logfix_aligned_dep = $cs_dep;
        } else {
            $logfix_aligned_dep = undef;
        }

        # mark in fixlog

        # my $distance = abs($gov->ord - $dep->ord);
        # warn "FIXDISTANCE: $distance\n";

        #original words pair
        if ( $gov->ord < $dep->ord ) {
            $logfixold = $gov->form;
            $logfixold .= "[";
            $logfixold .= $gov->tag;
            $logfixold .= "] ";
            $logfixold .= $dep->form;
            $logfixold .= "[";
            $logfixold .= $dep->tag;
            $logfixold .= "]";
        }
        else {
            $logfixold = $dep->form;
            $logfixold .= "[";
            $logfixold .= $dep->tag;
            $logfixold .= "] ";
            $logfixold .= $gov->form;
            $logfixold .= "[";
            $logfixold .= $gov->tag;
            $logfixold .= "]";
        }
    }
    else {
        $logfixold         = '(undefined node)';
        $logfixold_flt_gov = undef;
        $logfixold_flt_dep = undef;
    }

    return;
}

sub logfix2 {
    my ( $self, $node ) = @_;

    my $dep = undef;
    my $gov = undef;
    my $d   = undef;
    my $g   = undef;

    if (defined $node &&
        blessed $node &&
        !$node->isa('Treex::Core::Node::Deleted')
    ) {
        ( $dep, $gov, $d, $g ) = $self->get_pair($node);
        return if !$dep;

        #new words pair
        if ( $gov->ord < $dep->ord ) {
            $logfixnew = $gov->form;
            $logfixnew .= "[";
            $logfixnew .= $gov->tag;
            $logfixnew .= "] ";
            $logfixnew .= $dep->form;
            $logfixnew .= "[";
            $logfixnew .= $dep->tag;
            $logfixnew .= "] ";
        }
        else {
            $logfixnew = $dep->form;
            $logfixnew .= "[";
            $logfixnew .= $dep->tag;
            $logfixnew .= "] ";
            $logfixnew .= $gov->form;
            $logfixnew .= "[";
            $logfixnew .= $gov->tag;
            $logfixnew .= "] ";
        }
    }
    else {
        $logfixnew = '(removal)';
    }

    #output
    if ( $logfixold ne $logfixnew ) {

        # alignment link
        if (
            defined $gov && defined $logfix_aligned_gov
            && defined $logfixold_flt_gov && $logfixold_flt_gov ne $g->{flt}
            )
        {
            $logfix_aligned_gov->add_aligned_node( $gov, "depfix_$logfixmsg" );
        }
        if (
            defined $dep && defined $logfix_aligned_dep
            && defined $logfixold_flt_dep && $logfixold_flt_dep ne $d->{flt}
            )
        {
            $logfix_aligned_dep->add_aligned_node( $dep, "depfix_$logfixmsg" );
        }

        # FIXLOG
        if ( !defined $logfixbundle) {
            log_warn 'logfixbundle is undef';
        } else {
            my $fixlogzone = $logfixbundle->get_or_create_zone(
                $self->language, 'FIXLOG' );
            $fixlogzone->set_sentence( ($fixlogzone->sentence // '') .
                "{$logfixmsg: $logfixold -> $logfixnew} ");
        }
    }

    if ( $self->log_to_console ) {
        log_info("FIXLOG: $logfixmsg on sentence $logfixs node $logfixn: $logfixold -> $logfixnew");
    }

    return;
}

sub logfixNode {
    my ( $self, $node, $mess ) = @_;

    $node->id =~ /-s([0-9]+)-n([0-9]+)$/;
    my $sid = $1;
    my $nid = $2;
    
    my $bundle = $node->get_bundle();

    # FIXLOG
    if ( $bundle->get_zone( 'cs', 'FIXLOG' ) ) {
        my $sentence = $bundle->get_or_create_zone( 'cs', 'FIXLOG' )
        ->sentence . "{$mess} ";
        $bundle->get_zone( 'cs', 'FIXLOG' )->set_sentence($sentence);
    }
    else {
        my $sentence = "{$mess} ";
        $bundle->create_zone( 'cs', 'FIXLOG' )
        ->set_sentence($sentence);
    }

    if ( $self->log_to_console ) {
        log_info("FIXLOG: $mess on sentence $sid node $nid");
    }

    return;
}

sub logfixBundle {
    my ( $self, $bundle, $mess ) = @_;

    $bundle->id =~ /^s([0-9]+)$/;
    my $sid = $1;

    # FIXLOG
    if ( $bundle->get_zone( 'cs', 'FIXLOG' ) ) {
        my $sentence = $bundle->get_or_create_zone( 'cs', 'FIXLOG' )
        ->sentence . "{$mess} ";
        $bundle->get_zone( 'cs', 'FIXLOG' )->set_sentence($sentence);
    }
    else {
        my $sentence = "{$mess} ";
        $bundle->create_zone( 'cs', 'FIXLOG' )
        ->set_sentence($sentence);
    }

    if ( $self->log_to_console ) {
        log_info("FIXLOG: $mess on sentence $sid ");
    }

    return;
}

1;

=head1 NAME 

Treex::

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

