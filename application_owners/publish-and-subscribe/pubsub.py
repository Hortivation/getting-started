import abc
import pika
import time
import traceback
import threading
from pika.adapters.blocking_connection import BlockingChannel
from typing import Dict, Any


#########################################################################################
# RabbitMQ Subscriptions ################################################################
#########################################################################################

class RMQSubscription(threading.Thread):
    """Base class of a RabbitMQ subscription"""

    def __init__(
        self,
        username: str,
        password: str,
        host: str,
        topic: str,
    ):
        """Initialize base RabbitMQ subscription class

        Parameters
        ----------
        username : str
            Username of the RabbitMQ user
        password : str
            Password of the RabbitMQ user
        host : str
            Host of the message broker
        topic : str
            Topic to subscribe to with a
            '<organization>.<datasource>.<dataset>' format
        """
        super().__init__()
        credentials = pika.PlainCredentials(username, password)
        self.connection = pika.BlockingConnection(
            pika.ConnectionParameters(host=host, credentials=credentials)
        )
        self.channel = self.connection.channel()
        self.topic = topic

        self.channel.exchange_declare(exchange=self.topic, exchange_type="fanout")
        result = self.channel.queue_declare(queue="", exclusive=True)
        self.queue_name = result.method.queue
        self.channel.queue_bind(exchange=self.topic, queue=self.queue_name)
        self.consumer_tag = self.channel.basic_consume(
            queue=self.queue_name, on_message_callback=self.callback, auto_ack=True
        )

    @abc.abstractmethod
    def callback(
        self, channel: BlockingChannel, method: Any, properties: Any, body: bytes
    ):
        """(ABSTRACT) Callback method of subscription called after receiving a
        message from the broker.

        Parameters
        ----------
        channel : BlockingChannel
            The channel of the subscription
        method : Any
            pika Deliver object
        properties : Any
            pike BasicProperties object
        body : bytes
            Body of the received message in bytes. Usually one of the
            messages below:
            - metadata edited
            - content edited
        """
        pass

    def run(self):
        """Start consuming the subscription"""
        try:
            res = self.channel.start_consuming()
        except Exception as e:
            error_message = traceback.format_exc()

    def kill(self):
        """Kill the subscription"""
        try:
            self.channel.basic_cancel(self.consumer_tag)
        except Exception as e:
            error_message = traceback.format_exc()


class RMQSubscriptionPrint(RMQSubscription):
    """RabbitMQ subscription that prints received messages"""

    def __init__(
        self,
        username: str,
        password: str,
        host: str,
        topic: str,
    ):
        """Initialize print message RabbitMQ subscription class

        Parameters
        ----------
        username : str
            Username of the RabbitMQ user
        password : str
            Password of the RabbitMQ user
        host : str
            Host of the message broker
        topic : str
            Topic to subscribe to with a
            '<organization>.<datasource>.<dataset>' format
        """
        super().__init__(username, password, host, topic)

    def callback(
        self, channel: BlockingChannel, method: Any, properties: Any, body: bytes
    ):
        """Callback method of subscription called after receiving a
        message from the broker.

        Parameters
        ----------
        channel : BlockingChannel
            The channel of the subscription
        method : Any
            pika Deliver object
        properties : Any
            pike BasicProperties object
        body : bytes
            Body of the received message in bytes. Usually one of the
            messages below:
            - metadata edited
            - content edited
        """
        print(f"\t[{self.topic}] received '{str(body)}'")



#########################################################################################
# RabbitMQ Client #######################################################################
#########################################################################################

class RMQClient:
    """RabbitMQ client object that is able to publish messages and handle multiple
    subscriptions.
    """

    def __init__(
        self,
        username: str,
        password: str,
        host: str = "localhost",
    ):
        """Initialize the RabbitMQ client object and setup connection
        to the message broker.

        NOTE: see your datasource credentials file for details about the
        RabbitMQ user and host.

        Parameters
        ----------
        username : str
            Username of the RabbitMQ user
        password : str
            Password of the RabbitMQ user
        host : str, optional
            Host of the RabbitMQ message broker, by default "localhost"
        """
        self.username = username
        self.password = password
        self.host = host

        # Initialize subscriptions
        self.subscriptions: Dict[str, RMQSubscription] = {}

        # Setup connection to RMQ server
        self._connection = self.create_connection()
        self._channel = self._connection.channel()

    def create_connection(self) -> pika.BlockingConnection:
        """Create a new connection to the RabbitMQ message broker

        Returns
        -------
        pika.BlockingConnection
            Connection object to the RabbitMQ server
        """
        credentials = pika.PlainCredentials(self.username, self.password)
        for _ in range(5):
            try:
                connection: pika.BlockingConnection = pika.BlockingConnection(
                    pika.ConnectionParameters(host=self.host, credentials=credentials)
                )
                return connection
            except Exception as e:
                error_message = traceback.format_exc()
                time.sleep(1)  # Wait 1 second before next retry
        assert False, f"Failed to connect to RabbitMQ!"

    def publish(self, topic: str, message: str):
        """Publish a message to an topic

        Parameters
        ----------
        topic : str
            Topic to publish a message to
        message : str
            Message that you want to send to all subscribers of this topic.
        """
        self._channel.exchange_declare(exchange=topic, exchange_type="fanout")
        self._channel.basic_publish(exchange=topic, routing_key="", body=message)

    def subscribe(self, topic: str, action: str = "print"):
        """Subscribe to an topic

        Parameters
        ----------
        topic : str
            Topic with a '<organization>.<datasource>.<dataset>' format
        action : str, optional
            Currently only 'print' is supported, but it is possible to implement
            a custom subscription, by default "print"
        """
        if topic in self.subscriptions:
            print(
                f"Already subscribed to this topic, cannot have multiple subscriptions to the same topic!"
            )
            return

        if action == "print":
            s = RMQSubscriptionPrint(self.username, self.password, self.host, topic)
        else:
            print(
                f"NOT YET IMPLEMENTED: action:{action} is not known! Please create a new Subscription class from the RMQSubscription template and implement the callback function."
            )
            return

        s.start()
        self.subscriptions[topic] = s

    def unsubscribe(self, topic: str):
        """Unsubscribe from an topic

        Parameters
        ----------
        topic : str
            Topic with a '<organization>.<datasource>.<dataset>' format
        """
        if topic in self.subscriptions:
            self.subscriptions[topic].kill()
            del self.subscriptions[topic]

    def close(self):
        """Unsubscribe from all open subscriptions and close the connection
        to the RabbitMQ message broker
        """
        try:
            for topic in self.subscriptions:
                self.unsubscribe(topic)
            self._connection.close()
        except Exception as e:
            error_message = traceback.format_exc()
