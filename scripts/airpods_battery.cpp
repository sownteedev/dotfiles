#include <QBluetoothAddress>
#include <QBluetoothServiceInfo>
#include <QBluetoothSocket>
#include <QBluetoothUuid>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#include <cstdio>
#include <csignal>
#include <sys/prctl.h>
#include <unistd.h>

namespace {
const auto serviceUuid = QStringLiteral("74ec2172-0bad-4d01-8f77-997b2be0722a");
const auto handshake = QByteArray::fromHex("00000400010002000000000000000000");
const auto handshakeAck = QByteArray::fromHex("01000400");
const auto setSpecificFeatures = QByteArray::fromHex("040004004d00d700000000000000");
const auto featuresAck = QByteArray::fromHex("040004002b00");
const auto requestNotifications = QByteArray::fromHex("040004000f00ffffffffff");
const auto batteryHeader = QByteArray::fromHex("040004000400");
}

class AirPodsBatteryReader final : public QObject {
public:
    explicit AirPodsBatteryReader(const QString &address) : address_(address) {
        socket_ = new QBluetoothSocket(QBluetoothServiceInfo::L2capProtocol, this);
        connect(socket_, &QBluetoothSocket::connected, this, [this] { socket_->write(handshake); });
        connect(socket_, &QBluetoothSocket::readyRead, this, [this] {
            received_.append(socket_->readAll());
            processReceivedData();
        });
        connect(socket_, &QBluetoothSocket::errorOccurred, this,
                [this](QBluetoothSocket::SocketError) {
                    if (batteryReceived_)
                        QCoreApplication::exit(0);
                    else
                        finishUnavailable(socket_->errorString());
                });

        QTimer::singleShot(9000, this, [this] {
            if (!batteryReceived_)
                finishUnavailable(QStringLiteral("Timed out waiting for battery status"));
        });
        socket_->connectToService(QBluetoothAddress(address_), QBluetoothUuid(serviceUuid));
    }

private:
    void processReceivedData() {
        if (!featuresSent_ && received_.contains(handshakeAck)) {
            featuresSent_ = true;
            socket_->write(setSpecificFeatures);
        }
        if (!notificationsSent_ && received_.contains(featuresAck)) {
            notificationsSent_ = true;
            socket_->write(requestNotifications);
        }

        while (true) {
            const int start = received_.indexOf(batteryHeader);
            if (start < 0) {
                if (received_.size() > 4096)
                    received_ = received_.right(batteryHeader.size() - 1);
                return;
            }
            if (received_.size() < start + 7)
                return;
            const quint8 count = static_cast<quint8>(received_.at(start + 6));
            const int packetSize = 7 + 5 * count;
            if (count > 3) {
                received_.remove(0, start + batteryHeader.size());
                continue;
            }
            if (received_.size() < start + packetSize)
                return;
            parseBatteryPacket(received_.mid(start, packetSize));
            received_.remove(0, start + packetSize);
        }
    }

    void parseBatteryPacket(const QByteArray &packet) {
        QJsonObject result{{"available", true},
                           {"accurate", true},
                           {"address", address_},
                           {"left", QJsonValue::Null},
                           {"right", QJsonValue::Null},
                           {"case", QJsonValue::Null},
                           {"leftAvailable", false},
                           {"rightAvailable", false},
                           {"caseAvailable", false},
                           {"leftCharging", false},
                           {"rightCharging", false},
                           {"caseCharging", false}};

        const quint8 count = static_cast<quint8>(packet.at(6));
        for (quint8 i = 0; i < count; ++i) {
            const int offset = 7 + 5 * i;
            if (static_cast<quint8>(packet.at(offset + 1)) != 0x01 ||
                static_cast<quint8>(packet.at(offset + 4)) != 0x01) {
                finishUnavailable(QStringLiteral("Malformed battery packet"));
                return;
            }

            const quint8 component = static_cast<quint8>(packet.at(offset));
            const int level = static_cast<quint8>(packet.at(offset + 2));
            const quint8 status = static_cast<quint8>(packet.at(offset + 3));
            QString key;
            if (component == 0x04)
                key = QStringLiteral("left");
            else if (component == 0x02)
                key = QStringLiteral("right");
            else if (component == 0x08)
                key = QStringLiteral("case");
            else
                continue;

            const bool componentAvailable = level <= 100 && (status == 0x01 || status == 0x02);
            if (componentAvailable)
                result[key] = level;
            result[key + QStringLiteral("Available")] = componentAvailable;
            result[key + QStringLiteral("Charging")] = componentAvailable && status == 0x01;
        }

        batteryReceived_ = true;
        emitResult(result);
    }

    void finishUnavailable(const QString &error) {
        if (finished_)
            return;
        finished_ = true;
        emitResult(QJsonObject{{"available", false},
                               {"accurate", false},
                               {"address", address_},
                               {"error", error}});
        socket_->close();
        QCoreApplication::exit(1);
    }

    void emitResult(const QJsonObject &result) {
        const QByteArray json = QJsonDocument(result).toJson(QJsonDocument::Compact);
        std::fwrite(json.constData(), 1, static_cast<size_t>(json.size()), stdout);
        std::fputc('\n', stdout);
        std::fflush(stdout);
    }

    QString address_;
    QBluetoothSocket *socket_ = nullptr;
    QByteArray received_;
    bool featuresSent_ = false;
    bool notificationsSent_ = false;
    bool batteryReceived_ = false;
    bool finished_ = false;
};

int main(int argc, char **argv) {
    const pid_t parentPid = getppid();
    if (prctl(PR_SET_PDEATHSIG, SIGTERM) != 0 || getppid() != parentPid)
        return 1;

    QCoreApplication app(argc, argv);
    if (argc != 2) {
        std::fprintf(stderr, "Usage: %s BLUETOOTH_ADDRESS\n", argv[0]);
        return 2;
    }
    AirPodsBatteryReader reader(QString::fromLocal8Bit(argv[1]));
    return app.exec();
}
