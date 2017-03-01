package Treex::Tool::Tagger::HunPoS;

use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::ProcessUtils;
use Treex::Core::Resource;
with 'Treex::Tool::Tagger::Role';


has model => ( isa => 'Str', is => 'rw', required => 1 );
has [qw( _reader _writer _pid )] => ( is => 'rw' );


sub BUILD {
    my $self = shift;

    my $executable = require_file_from_share( 
        'tagger/hunpostagger/hunpos-1.0-linux/hunpos-tag',
        ref( $self ),
    );

     my $command = "$executable -token -tag -no-unknown " . $self->model . ' 2>/dev/null';

    
    my ( $reader, $writer, $pid ) = Treex::Tool::ProcessUtils::bipipe( $command, ':encoding(utf-8)' );
    $self->_set_reader($reader);
    $self->_set_writer($writer);
    $self->_set_pid($pid);

    # writes to the input three technical tokens as a sentence separator
    print $writer ".\n.\n.\n";

    return;
}

sub tag_sentence {
    my $self = shift;
    my $toks = shift;
    return [] if scalar @$toks == 0;

    my $htwr = $self->_writer;
    my $htrd = $self->_reader;

    # tokens to force end of sentence
    my $cnt = 0;
    
      # input tokens
    foreach my $tok (@$toks) {
        print $htwr $tok . "\n";
        $cnt++;
        
    }
    
     # input sentence separator
##    print $htwr ".\n.\n.\n";
    
   
    my @tags   = ();
    my @lemmas = ();
    
     # skip sentence separator
    for ( my $i = 0; $i < 3; $i++ ) {
        my $got = <$htrd>;
    }
    
    
  # read output
    while ( $cnt > 0 ) {
        my $got = <$htrd>;
        chomp $got;
        my @items = split( /\t/, $got );
        $cnt--;
        
        my $i=scalar(@lemmas);
        my $form=$toks->[$i];
        my $lemma=$items[2];
        if ($lemma eq '@card@') {
            $lemma=$form;
        }
        my $tag = $items[1];
        
        push @tags,   $tag;
        push @lemmas, $lemma;
    }

    return \@tags, \@lemmas;
   
}

sub DEMOLISH {
    my ($self) = @_;
    close( $self->_writer );
    close( $self->_reader );
    Treex::Tool::ProcessUtils::safewaitpid( $self->_pid );
    return;
}

1;

__END__


=head1 NAME 

Treex::Tool::Tagger::HunPoS

=head1 DESCRIPTION

This is a Perl wrapper for HunPoS tagger implemented in OCaml.

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>


=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

