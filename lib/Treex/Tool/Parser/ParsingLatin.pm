package Treex::Tool::Parser::ParsingLatin;
use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Core::Resource;
use Treex::Tool::ProcessUtils;

with 'Treex::Tool::Parser::Role';

has model      => ( isa => 'Str', is => 'rw', required => 1);

sub BUILD {
    my ($self) = @_;
    my $exec = Treex::Core::Config->share_dir."/parser/Parsing_Latin/pipeline/pipeline.sh";
    my $cmd = system("bash $exec -c").' 2>/dev/null';
 
    # start ParsingLatin
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe( $cmd, ':encoding(utf-8)' );    

    $self->{reader} = $reader;
    $self->{writer} = $writer;
    $self->{pid}    = $pid;

    return;

}

sub parse_sentence {
    my ( $self, $forms, $lemmas, $cpostags, $postags, $feats ) = @_;

    my $cnt = scalar @$forms;
    $self->write();
    $self->write();
    for ( my $i = 0; $i < $cnt; $i++ ) {
        $self->write(($i+1) . "\t$$forms[$i]\t$$lemmas[$i]\t$$cpostags[$i]\t$$postags[$i]\t$$feats[$i]\t_\t_\t_\t_");
    }
    $self->write();
    $self->write();

    # read output
    my @parents = ();
    my @deprels = ();
    
    log_debug("$cnt to read", 1);
    my $line = $self->read();
    while ($line eq '') {
        $line = $self->read();
    }
    while ( $cnt > 0 ) {
        if ($line ne '') {
            $cnt--;
            my ($tokid, $form, $lemma, $cpostag, $postag, $feat, $parent, $deprel, $pparent, $pdeprel) = split(/\t/, $line);
            push @parents, $parent;
            push @deprels, $deprel;
            
        } else {
            log_fatal "Unexpected empty line";
        }
        log_debug("$cnt to read", 1);
        $line = $self->read();
    }

    return ( \@parents, \@deprels );
}

1;

__END__


=head1 NAME

Treex::Tool::Parser::ParsingLatin

=head1 SYNOPSIS

  

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>


=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
