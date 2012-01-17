package Treex::Tool::Wordnet::SimpleQuery;
use Moose;
use Treex::Core::Common;

use DBI;
use File::Spec;
use Memoize;

# use utf8;

has 'language' => ( isa => 'Str', is => 'ro', required => 1 );

# Resources directory (should contain the Wordnet database file under a two-char language subdirectory)
has 'resource_dir' => ( isa => 'Str', is => 'ro', default => 'data/resources/wordnet3.0' );

# Wordnet SQLite database file
has 'wn_file' => ( isa => 'Str', is => 'ro', default => 'simple-wn-2.0.sqlite' );

# Database connection
has '_dbh' => ( is => 'rw' );

# WTF ?
has '_find_by_literal_stm' => ( is => 'rw' );

#---------------------------------
# class methods
#---------------------------------

sub BUILD {

    my ($self) = @_;

    my $data_path = Treex::Core::Resource::require_file_from_share(
        $self->resource_dir . '/' . $self->language . '/' . $self->wn_file
    );
    
    my $db_options = {
        PrintError     => 1,
        RaiseError     => 1,
        sqlite_unicode => 1,
    };

    my $dbh = DBI->connect( "dbi:SQLite:dbname=" . $data_path, qw(), qw(), $db_options )
        || log_fatal("Unable to open sqlite db file.");
    # seems like db_options have no mojo :(
    $dbh->{sqlite_unicode} = 1;

    my $find_by_literal_stm = $dbh->prepare('select * from t where literal_pos = ? order by sense asc');
    
    $self->_set_dbh( $dbh );
    $self->_set_find_by_literal_stm( $find_by_literal_stm );
}

memoize 'find_by_literal';

sub find_by_literal {
    my ( $self, $literal ) = @_;

    my @result = @{ $self->_dbh->selectall_arrayref( $self->_find_by_literal_stm, { Slice => {} }, $literal ) };
    return @result;
}


sub DESTROY {
    my ($self) = @_;
    if ( defined $self->_find_by_literal_stm ) { 
        $self->_find_by_literal_stm->finish(); 
    }
    $self->_set_find_by_literal_stm( undef );
    if ( defined $self->_dbh ) { 
        $self->_dbh->disconnect(); 
    }
    $self->_set_dbh( undef );
}

1;

__END__

=head1 NAME

Treex::Tool::Wordnet::SimpleQuery

=head1 VERSION

0.1

=head1 SYNOPSIS

 use Wordnet::SimpleQuery;

 # accepted sense_keys are:
 #      sense keys in form lemma-pos

 my $wordnet = Wordnet::SimpleQuery->new();
 my @result  = $wordnet->find_by_literal($sense_key);

=head1 DESCRIPTION

Perl module for querying sqlite table containing partial wordnet knowledge.
Optimized for quick retrieval - just one flat table, no joins.

=head1 AUTHORS

Jan Ptáček

Ondřej Dušek

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
